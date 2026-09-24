import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../domain/client_security.dart';

class SecureClientSecretStore implements ClientSecretStore {
  SecureClientSecretStore({FlutterSecureStorage? storage})
    : _storage =
          storage ??
          const FlutterSecureStorage(
            aOptions: AndroidOptions(
              storageNamespace: 'libreslip_client_secrets',
              resetOnError: false,
            ),
          );

  static const _tokenPrefix = 'server_access_token_';

  final FlutterSecureStorage _storage;

  @override
  Future<String?> readServerAccessToken(String serverId) =>
      _storage.read(key: '$_tokenPrefix$serverId');

  @override
  Future<void> writeServerAccessToken(String serverId, String token) =>
      _storage.write(key: '$_tokenPrefix$serverId', value: token);

  @override
  Future<void> deleteServerAccessToken(String serverId) =>
      _storage.delete(key: '$_tokenPrefix$serverId');
}
