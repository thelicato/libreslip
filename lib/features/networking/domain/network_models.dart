import 'dart:math';

enum LibreSlipMode { client, server }

extension LibreSlipModeValue on LibreSlipMode {
  String get value => name;

  static LibreSlipMode parse(String value) => switch (value) {
    'client' => LibreSlipMode.client,
    'server' => LibreSlipMode.server,
    _ => throw const FormatException('Unsupported LibreSlip mode'),
  };
}

class NetworkConfiguration {
  const NetworkConfiguration({
    required this.mode,
    required this.installationId,
    required this.serverName,
  });

  final LibreSlipMode mode;
  final String installationId;
  final String serverName;

  NetworkConfiguration copyWith({LibreSlipMode? mode, String? serverName}) =>
      NetworkConfiguration(
        mode: mode ?? this.mode,
        installationId: installationId,
        serverName: serverName ?? this.serverName,
      );
}

abstract interface class NetworkConfigurationStore {
  Future<NetworkConfiguration> loadNetworkConfiguration();

  Future<void> saveLibreSlipMode(LibreSlipMode mode);
}

String createInstallationId() {
  final random = Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  return bytes.map((value) => value.toRadixString(16).padLeft(2, '0')).join();
}
