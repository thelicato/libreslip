import 'dart:convert';
import 'dart:math';

import 'package:basic_utils/basic_utils.dart';
import 'package:crypto/crypto.dart';

import '../domain/server_security.dart';

class ServerIdentityService {
  const ServerIdentityService(this._store);

  final ServerSecretStore _store;

  Future<ServerIdentity> loadOrCreate() async {
    final certificate = await _store.readServerCertificate();
    final privateKey = await _store.readServerPrivateKey();
    if (certificate != null && privateKey != null) {
      return _identity(certificate, privateKey);
    }

    final pair = CryptoUtils.generateRSAKeyPair(keySize: 2048);
    final rsaPrivate = pair.privateKey as RSAPrivateKey;
    final rsaPublic = pair.publicKey as RSAPublicKey;
    final distinguishedName = <String, String>{
      'CN': 'LibreSlip local server',
      'O': 'LibreSlip',
    };
    final request = X509Utils.generateRsaCsrPem(
      distinguishedName,
      rsaPrivate,
      rsaPublic,
      san: const ['libreslip.local', 'localhost'],
    );
    final serial = (Random.secure().nextInt(0x7fffffff) + 1).toString();
    final newCertificate = X509Utils.generateSelfSignedCertificate(
      rsaPrivate,
      request,
      3650,
      sans: const ['libreslip.local', 'localhost'],
      extKeyUsage: const [ExtendedKeyUsage.SERVER_AUTH],
      serialNumber: serial,
    );
    final newPrivateKey = CryptoUtils.encodeRSAPrivateKeyToPem(rsaPrivate);
    await _store.writeServerIdentity(
      certificatePem: newCertificate,
      privateKeyPem: newPrivateKey,
    );
    return _identity(newCertificate, newPrivateKey);
  }

  static ServerIdentity _identity(String certificate, String privateKey) {
    final der = CryptoUtils.getBytesFromPEMString(certificate);
    return ServerIdentity(
      certificatePem: certificate,
      privateKeyPem: privateKey,
      certificateFingerprint: sha256.convert(der).toString(),
    );
  }
}

String createAccessToken() {
  final random = Random.secure();
  final bytes = List<int>.generate(32, (_) => random.nextInt(256));
  return base64UrlEncode(bytes).replaceAll('=', '');
}

String hashAccessToken(String token) =>
    sha256.convert(utf8.encode(token)).toString();
