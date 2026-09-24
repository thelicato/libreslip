import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../domain/server_security.dart';

class SecureServerSecretStore implements ServerSecretStore {
  SecureServerSecretStore({FlutterSecureStorage? storage})
    : _storage =
          storage ??
          const FlutterSecureStorage(
            aOptions: AndroidOptions(
              storageNamespace: 'libreslip_server_secrets',
              resetOnError: false,
            ),
          );

  static const _certificateKey = 'server_certificate_pem';
  static const _privateKey = 'server_private_key_pem';
  static const _clientTokenPrefix = 'client_token_sha256_';

  final FlutterSecureStorage _storage;

  @override
  Future<String?> readServerCertificate() =>
      _storage.read(key: _certificateKey);

  @override
  Future<String?> readServerPrivateKey() => _storage.read(key: _privateKey);

  @override
  Future<void> writeServerIdentity({
    required String certificatePem,
    required String privateKeyPem,
  }) async {
    await _storage.write(key: _privateKey, value: privateKeyPem);
    await _storage.write(key: _certificateKey, value: certificatePem);
  }

  @override
  Future<String?> readClientTokenHash(String clientInstallationId) =>
      _storage.read(key: '$_clientTokenPrefix$clientInstallationId');

  @override
  Future<void> writeClientTokenHash(
    String clientInstallationId,
    String tokenHash,
  ) => _storage.write(
    key: '$_clientTokenPrefix$clientInstallationId',
    value: tokenHash,
  );
}
