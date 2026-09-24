abstract interface class ClientSecretStore {
  Future<String?> readServerAccessToken(String serverId);

  Future<void> writeServerAccessToken(String serverId, String token);

  Future<void> deleteServerAccessToken(String serverId);
}
