abstract interface class ServerRuntimeService {
  Future<void> start();

  Future<void> stop();
}

class NoopServerRuntimeService implements ServerRuntimeService {
  const NoopServerRuntimeService();

  @override
  Future<void> start() async {}

  @override
  Future<void> stop() async {}
}
