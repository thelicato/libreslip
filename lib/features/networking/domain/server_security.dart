class ServerIdentity {
  const ServerIdentity({
    required this.certificatePem,
    required this.privateKeyPem,
    required this.certificateFingerprint,
  });

  final String certificatePem;
  final String privateKeyPem;
  final String certificateFingerprint;
}

abstract interface class ServerSecretStore {
  Future<String?> readServerCertificate();

  Future<String?> readServerPrivateKey();

  Future<void> writeServerIdentity({
    required String certificatePem,
    required String privateKeyPem,
  });

  Future<String?> readClientTokenHash(String clientInstallationId);

  Future<void> writeClientTokenHash(
    String clientInstallationId,
    String tokenHash,
  );
}
