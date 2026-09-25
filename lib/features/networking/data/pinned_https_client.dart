import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

import '../domain/client_delivery_models.dart';
import '../domain/client_transport.dart';
import '../domain/network_protocol.dart';

class PinnedHttpsClient implements ClientServerTransport {
  const PinnedHttpsClient();

  static const _responseLimit = 16384;
  static final _fingerprintPattern = RegExp(r'^[0-9a-f]{64}$');
  static final _identifierPattern = RegExp(
    r'^[A-Za-z0-9][A-Za-z0-9._:-]{0,127}$',
  );

  static Uri normaliseServerAddress(String value) {
    final source = value.trim();
    final withScheme = source.contains('://') ? source : 'https://$source';
    final parsed = Uri.tryParse(withScheme);
    if (parsed == null ||
        parsed.scheme != 'https' ||
        parsed.host.isEmpty ||
        parsed.userInfo.isNotEmpty ||
        parsed.hasQuery ||
        parsed.hasFragment ||
        (parsed.path.isNotEmpty && parsed.path != '/')) {
      throw const FormatException('Invalid server address');
    }
    final address = InternetAddress.tryParse(parsed.host);
    if (address == null ||
        address.type != InternetAddressType.IPv4 ||
        !_isLocalIpv4(address.rawAddress)) {
      throw const FormatException('A local IPv4 address is required');
    }
    final port = parsed.hasPort ? parsed.port : NetworkProtocol.defaultPort;
    if (port < 1 || port > 65535) {
      throw const FormatException('Invalid server port');
    }
    return Uri(scheme: 'https', host: parsed.host, port: port);
  }

  static bool _isLocalIpv4(List<int> bytes) {
    if (bytes.length != 4) return false;
    return bytes[0] == 10 ||
        bytes[0] == 127 ||
        (bytes[0] == 169 && bytes[1] == 254) ||
        (bytes[0] == 172 && bytes[1] >= 16 && bytes[1] <= 31) ||
        (bytes[0] == 192 && bytes[1] == 168);
  }

  @override
  Future<PairServerResult> pair(PairServerRequest request) async {
    if (!_identifierPattern.hasMatch(request.clientInstallationId) ||
        request.clientDisplayName.trim().isEmpty ||
        request.clientDisplayName.trim().length > 80 ||
        !_fingerprintPattern.hasMatch(request.clientIdentityFingerprint)) {
      throw const ClientTransportException('invalid_pairing');
    }
    final baseUrl = normaliseServerAddress(request.baseUrl.toString());
    final discovery = await _requestFirstContact(baseUrl.resolve('/v1/status'));
    final status = discovery.response;
    final fingerprint = discovery.certificateFingerprint;
    if (status.statusCode != HttpStatus.ok ||
        status.body['protocol'] != NetworkProtocol.name ||
        status.body['version'] != NetworkProtocol.version ||
        status.body['certificateFingerprint'] != fingerprint ||
        status.body['serverInstallationId'] is! String ||
        status.body['serverName'] is! String) {
      throw const ClientTransportException('server_identity');
    }
    final serverId = status.body['serverInstallationId']! as String;
    final serverName = (status.body['serverName']! as String).trim();
    if (!_identifierPattern.hasMatch(serverId) ||
        serverName.isEmpty ||
        serverName.length > 80) {
      throw const ClientTransportException('server_identity');
    }
    final pairing = await _request(
      baseUrl.resolve('/v1/pair'),
      fingerprint: fingerprint,
      responseTimeout: const Duration(minutes: 2, seconds: 10),
      body: {
        'clientInstallationId': request.clientInstallationId,
        'displayName': request.clientDisplayName.trim(),
        'clientIdentityFingerprint': request.clientIdentityFingerprint,
      },
    );
    if (pairing.statusCode == HttpStatus.forbidden) {
      throw const ClientTransportException('pairing_denied');
    }
    if (pairing.statusCode != HttpStatus.created ||
        pairing.body['protocol'] != NetworkProtocol.name ||
        pairing.body['version'] != NetworkProtocol.version ||
        pairing.body['serverInstallationId'] != serverId ||
        pairing.body['certificateFingerprint'] != fingerprint ||
        pairing.body['accessToken'] is! String ||
        (pairing.body['accessToken']! as String).isEmpty) {
      throw const ClientTransportException('invalid_response');
    }
    final now = DateTime.now().toUtc();
    return PairServerResult(
      server: PairedServer(
        id: serverId,
        displayName: serverName,
        baseUrl: baseUrl,
        certificateFingerprint: fingerprint,
        createdAt: now,
        updatedAt: now,
      ),
      accessToken: pairing.body['accessToken']! as String,
    );
  }

  @override
  Future<DeliveryAcknowledgement> deliver({
    required PairedServer server,
    required String accessToken,
    required ClientDelivery delivery,
  }) async {
    if (accessToken.isEmpty ||
        delivery.destinationId != server.id ||
        delivery.envelope.clientInstallationId !=
            delivery.clientInstallationId) {
      throw const ClientTransportException('credentials');
    }
    final response = await _request(
      server.baseUrl.resolve('/v1/orders'),
      fingerprint: server.certificateFingerprint,
      body: delivery.envelope.toJson(),
      headers: {
        HttpHeaders.authorizationHeader: 'Bearer $accessToken',
        'X-LibreSlip-Client-Id': delivery.clientInstallationId,
      },
    );
    if (response.statusCode == HttpStatus.unauthorized ||
        response.statusCode == HttpStatus.forbidden) {
      throw const ClientTransportException('unauthorised');
    }
    if (response.statusCode == HttpStatus.conflict) {
      throw const ClientTransportException('conflict');
    }
    if (response.statusCode != HttpStatus.created &&
        response.statusCode != HttpStatus.ok) {
      throw ClientTransportException(
        response.statusCode >= 500 ? 'server' : 'rejected',
      );
    }
    final body = response.body;
    if (body['protocol'] != NetworkProtocol.name ||
        body['version'] != NetworkProtocol.version ||
        body['deliveryId'] != delivery.id ||
        body['serverOrderId'] is! String ||
        body['duplicate'] is! bool) {
      throw const ClientTransportException('invalid_response');
    }
    return DeliveryAcknowledgement(
      deliveryId: delivery.id,
      serverOrderId: body['serverOrderId']! as String,
      duplicate: body['duplicate']! as bool,
    );
  }

  Future<_FirstContactResponse> _requestFirstContact(Uri uri) async {
    String? callbackFingerprint;
    final context = SecurityContext(withTrustedRoots: false);
    final client = HttpClient(context: context)
      ..connectionTimeout = const Duration(seconds: 5)
      ..idleTimeout = const Duration(seconds: 10)
      ..badCertificateCallback = (certificate, host, port) {
        final actual = sha256.convert(certificate.der).toString();
        if (callbackFingerprint != null && callbackFingerprint != actual) {
          return false;
        }
        callbackFingerprint = actual;
        return true;
      };
    try {
      final request = await client.getUrl(uri);
      request.followRedirects = false;
      request.headers.set(HttpHeaders.acceptHeader, ContentType.json.mimeType);
      final response = await request.close().timeout(
        const Duration(seconds: 10),
      );
      final certificate = response.certificate;
      final fingerprint = certificate == null
          ? callbackFingerprint
          : sha256.convert(certificate.der).toString();
      if (fingerprint == null ||
          !_fingerprintPattern.hasMatch(fingerprint) ||
          (callbackFingerprint != null && callbackFingerprint != fingerprint)) {
        throw const ClientTransportException('certificate');
      }
      return _FirstContactResponse(
        await _readResponse(response, const Duration(seconds: 10)),
        fingerprint,
      );
    } on ClientTransportException {
      rethrow;
    } on HandshakeException {
      throw const ClientTransportException('certificate');
    } on FormatException {
      throw const ClientTransportException('invalid_response');
    } on SocketException {
      throw const ClientTransportException('unreachable');
    } on TimeoutException {
      throw const ClientTransportException('unreachable');
    } on HttpException {
      throw const ClientTransportException('unreachable');
    } finally {
      client.close(force: true);
    }
  }

  Future<_JsonResponse> _request(
    Uri uri, {
    required String fingerprint,
    Map<String, Object?>? body,
    Map<String, String> headers = const {},
    Duration responseTimeout = const Duration(seconds: 10),
  }) async {
    final context = SecurityContext(withTrustedRoots: false);
    final client = HttpClient(context: context)
      ..connectionTimeout = const Duration(seconds: 5)
      ..idleTimeout = responseTimeout
      ..badCertificateCallback = (certificate, host, port) =>
          sha256.convert(certificate.der).toString() == fingerprint;
    try {
      final request = body == null
          ? await client.getUrl(uri)
          : await client.postUrl(uri);
      request.followRedirects = false;
      request.headers.set(HttpHeaders.acceptHeader, ContentType.json.mimeType);
      for (final entry in headers.entries) {
        request.headers.set(entry.key, entry.value);
      }
      if (body != null) {
        request.headers.contentType = ContentType.json;
        request.write(jsonEncode(body));
      }
      final response = await request.close().timeout(responseTimeout);
      final certificate = response.certificate;
      if (certificate == null ||
          sha256.convert(certificate.der).toString() != fingerprint) {
        throw const ClientTransportException('certificate');
      }
      return await _readResponse(response, responseTimeout);
    } on ClientTransportException {
      rethrow;
    } on HandshakeException {
      throw const ClientTransportException('certificate');
    } on FormatException {
      throw const ClientTransportException('invalid_response');
    } on SocketException {
      throw const ClientTransportException('unreachable');
    } on TimeoutException {
      throw const ClientTransportException('unreachable');
    } on HttpException {
      throw const ClientTransportException('unreachable');
    } finally {
      client.close(force: true);
    }
  }

  Future<_JsonResponse> _readResponse(
    HttpClientResponse response,
    Duration timeout,
  ) async {
    final bytes = <int>[];
    await for (final chunk in response.timeout(timeout)) {
      bytes.addAll(chunk);
      if (bytes.length > _responseLimit) {
        throw const ClientTransportException('invalid_response');
      }
    }
    final decoded = jsonDecode(utf8.decode(bytes, allowMalformed: false));
    if (decoded is! Map<String, dynamic>) {
      throw const ClientTransportException('invalid_response');
    }
    return _JsonResponse(response.statusCode, decoded);
  }
}

class _FirstContactResponse {
  const _FirstContactResponse(this.response, this.certificateFingerprint);

  final _JsonResponse response;
  final String certificateFingerprint;
}

class _JsonResponse {
  const _JsonResponse(this.statusCode, this.body);

  final int statusCode;
  final Map<String, dynamic> body;
}
