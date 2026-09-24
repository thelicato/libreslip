import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../domain/network_models.dart';
import '../domain/network_protocol.dart';
import '../domain/server_inbox_models.dart';
import '../domain/server_security.dart';
import '../domain/server_transport.dart';
import 'server_identity_service.dart';

class LocalHttpsServer implements ServerHost {
  LocalHttpsServer(this._store, this._secrets, {this.port = 42837});

  static const _pairPath = '/v1/pair';
  static const _ordersPath = '/v1/orders';
  static const _statusPath = '/v1/status';
  static const _clientHeader = 'x-libreslip-client-id';
  static const _maxPairingBytes = 4096;

  final ServerInboxStore _store;
  final ServerSecretStore _secrets;
  final int port;
  HttpServer? _server;
  StreamSubscription<HttpRequest>? _subscription;

  @override
  Future<RunningServer> start({
    required ServerIdentity identity,
    required NetworkConfiguration configuration,
    required bool Function(String code) claimPairingCode,
    required void Function() onOrderReceived,
  }) async {
    final current = _server;
    if (current != null) {
      return RunningServer(
        port: current.port,
        addresses: await _localAddresses(current.port),
      );
    }
    final context = SecurityContext(withTrustedRoots: false)
      ..useCertificateChainBytes(utf8.encode(identity.certificatePem))
      ..usePrivateKeyBytes(utf8.encode(identity.privateKeyPem))
      ..minimumTlsProtocolVersion = TlsProtocolVersion.tls1_2;
    final server = await HttpServer.bindSecure(
      InternetAddress.anyIPv4,
      port,
      context,
    );
    server.serverHeader = 'LibreSlip';
    _server = server;
    _subscription = server.listen(
      (request) => unawaited(
        _handle(
          request,
          identity: identity,
          configuration: configuration,
          claimPairingCode: claimPairingCode,
          onOrderReceived: onOrderReceived,
        ),
      ),
    );
    return RunningServer(
      port: server.port,
      addresses: await _localAddresses(server.port),
    );
  }

  Future<void> _handle(
    HttpRequest request, {
    required ServerIdentity identity,
    required NetworkConfiguration configuration,
    required bool Function(String code) claimPairingCode,
    required void Function() onOrderReceived,
  }) async {
    request.response.headers.contentType = ContentType.json;
    request.response.persistentConnection = false;
    request.response.headers.set('cache-control', 'no-store');
    try {
      if (request.method == 'GET' && request.uri.path == _statusPath) {
        await _writeJson(request.response, HttpStatus.ok, {
          'protocol': NetworkProtocol.name,
          'version': NetworkProtocol.version,
          'serverInstallationId': configuration.installationId,
          'serverName': configuration.serverName,
          'certificateFingerprint': identity.certificateFingerprint,
        });
        return;
      }
      if (request.method == 'POST' && request.uri.path == _pairPath) {
        await _pair(
          request,
          identity: identity,
          configuration: configuration,
          claimPairingCode: claimPairingCode,
        );
        return;
      }
      if (request.method == 'POST' && request.uri.path == _ordersPath) {
        await _receiveOrder(request, onOrderReceived: onOrderReceived);
        return;
      }
      await _writeError(request.response, HttpStatus.notFound, 'not_found');
    } on _PayloadTooLargeException {
      await _writeError(
        request.response,
        HttpStatus.requestEntityTooLarge,
        'payload_too_large',
      );
    } on FormatException {
      await _writeError(
        request.response,
        HttpStatus.badRequest,
        'invalid_request',
      );
    } on ServerOrderConflictException {
      await _writeError(
        request.response,
        HttpStatus.conflict,
        'idempotency_conflict',
      );
    } catch (_) {
      await _writeError(
        request.response,
        HttpStatus.internalServerError,
        'server_error',
      );
    } finally {
      await request.response.close();
    }
  }

  Future<void> _pair(
    HttpRequest request, {
    required ServerIdentity identity,
    required NetworkConfiguration configuration,
    required bool Function(String code) claimPairingCode,
  }) async {
    _requireJson(request);
    final body = await _readBody(request, _maxPairingBytes);
    final decoded = jsonDecode(body);
    const keys = {
      'code',
      'clientInstallationId',
      'displayName',
      'clientIdentityFingerprint',
    };
    if (decoded is! Map<String, dynamic> ||
        decoded.keys.toSet().difference(keys).isNotEmpty ||
        !keys.every(decoded.containsKey) ||
        decoded.values.any((value) => value is! String)) {
      throw const FormatException('Invalid pairing request');
    }
    final code = decoded['code']! as String;
    final clientId = decoded['clientInstallationId']! as String;
    final displayName = (decoded['displayName']! as String).trim();
    final clientFingerprint = decoded['clientIdentityFingerprint']! as String;
    if (!_identifierPattern.hasMatch(clientId) ||
        displayName.isEmpty ||
        displayName.length > 80 ||
        !_fingerprintPattern.hasMatch(clientFingerprint)) {
      throw const FormatException('Invalid pairing identity');
    }
    if (!claimPairingCode(code)) {
      await _writeError(
        request.response,
        HttpStatus.forbidden,
        'pairing_denied',
      );
      return;
    }

    final token = createAccessToken();
    final now = DateTime.now().toUtc();
    await _secrets.writeClientTokenHash(clientId, hashAccessToken(token));
    await _store.pairClient(
      PairedClient(
        installationId: clientId,
        displayName: displayName,
        identityFingerprint: clientFingerprint,
        pairedAt: now,
      ),
    );
    await _writeJson(request.response, HttpStatus.created, {
      'protocol': NetworkProtocol.name,
      'version': NetworkProtocol.version,
      'serverInstallationId': configuration.installationId,
      'serverName': configuration.serverName,
      'certificateFingerprint': identity.certificateFingerprint,
      'accessToken': token,
    });
  }

  Future<void> _receiveOrder(
    HttpRequest request, {
    required void Function() onOrderReceived,
  }) async {
    _requireJson(request);
    final clientId = request.headers.value(_clientHeader);
    final authorization = request.headers.value(
      HttpHeaders.authorizationHeader,
    );
    if (clientId == null ||
        !_identifierPattern.hasMatch(clientId) ||
        authorization == null ||
        !authorization.startsWith('Bearer ')) {
      await _writeError(
        request.response,
        HttpStatus.unauthorized,
        'unauthorised',
      );
      return;
    }
    final client = await _store.findPairedClient(clientId);
    final expectedHash = await _secrets.readClientTokenHash(clientId);
    final suppliedHash = hashAccessToken(authorization.substring(7));
    if (client == null ||
        expectedHash == null ||
        !_constantTimeEquals(expectedHash, suppliedHash)) {
      await _writeError(
        request.response,
        HttpStatus.unauthorized,
        'unauthorised',
      );
      return;
    }
    final source = await _readBody(request, NetworkProtocol.maxEnvelopeBytes);
    final envelope = OrderDeliveryEnvelope.fromJsonString(source);
    if (envelope.clientInstallationId != clientId) {
      await _writeError(
        request.response,
        HttpStatus.forbidden,
        'client_mismatch',
      );
      return;
    }
    final receipt = await _store.receiveServerOrder(
      envelope,
      receivedAt: DateTime.now().toUtc(),
    );
    onOrderReceived();
    await _writeJson(
      request.response,
      receipt.wasDuplicate ? HttpStatus.ok : HttpStatus.created,
      {
        'protocol': NetworkProtocol.name,
        'version': NetworkProtocol.version,
        'deliveryId': envelope.deliveryId,
        'serverOrderId': receipt.order.id,
        'duplicate': receipt.wasDuplicate,
      },
    );
  }

  static void _requireJson(HttpRequest request) {
    final contentType = request.headers.contentType;
    if (contentType?.mimeType != ContentType.json.mimeType) {
      throw const FormatException('JSON is required');
    }
  }

  static Future<String> _readBody(HttpRequest request, int maximum) async {
    final declared = request.contentLength;
    if (declared > maximum) throw const _PayloadTooLargeException();
    final bytes = <int>[];
    await for (final chunk in request.timeout(const Duration(seconds: 10))) {
      bytes.addAll(chunk);
      if (bytes.length > maximum) throw const _PayloadTooLargeException();
    }
    return utf8.decode(bytes, allowMalformed: false);
  }

  static Future<void> _writeError(
    HttpResponse response,
    int status,
    String code,
  ) => _writeJson(response, status, {'error': code});

  static Future<void> _writeJson(
    HttpResponse response,
    int status,
    Map<String, Object?> body,
  ) async {
    response.statusCode = status;
    response.write(jsonEncode(body));
  }

  static bool _constantTimeEquals(String left, String right) {
    if (left.length != right.length) return false;
    var difference = 0;
    for (var index = 0; index < left.length; index++) {
      difference |= left.codeUnitAt(index) ^ right.codeUnitAt(index);
    }
    return difference == 0;
  }

  static Future<List<String>> _localAddresses(int port) async {
    final interfaces = await NetworkInterface.list(
      type: InternetAddressType.IPv4,
      includeLoopback: false,
    );
    final addresses = <String>{};
    for (final interface in interfaces) {
      for (final address in interface.addresses) {
        if (!address.isLinkLocal) {
          addresses.add('https://${address.address}:$port');
        }
      }
    }
    return addresses.toList()..sort();
  }

  @override
  Future<void> stop() async {
    final subscription = _subscription;
    _subscription = null;
    await subscription?.cancel();
    final server = _server;
    _server = null;
    await server?.close(force: true);
  }

  static final _identifierPattern = RegExp(
    r'^[A-Za-z0-9][A-Za-z0-9._:-]{0,127}$',
  );
  static final _fingerprintPattern = RegExp(r'^[0-9a-f]{64}$');
}

class _PayloadTooLargeException implements Exception {
  const _PayloadTooLargeException();
}
