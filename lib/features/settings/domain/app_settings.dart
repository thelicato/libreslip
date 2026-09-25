import 'package:flutter/material.dart';

import '../../printing/domain/ticket_typography.dart';

/// Preferences only. Items and ticket data belongs in SQLite.
@immutable
class AppSettings {
  const AppSettings({
    this.heading = '',
    this.footer = '',
    this.logoPath,
    this.typography = const TicketTypography(),
    this.language = 'en',
    this.themeMode = ThemeMode.system,
    this.appTextScale = defaultAppTextScale,
    this.preferredPrinterAddress,
  });

  final String heading;
  final String footer;
  final String? logoPath;
  final TicketTypography typography;
  static const minAppTextScale = 1.0;
  static const defaultAppTextScale = 1.0;
  static const maxAppTextScale = 1.3;

  final String language;
  final ThemeMode themeMode;
  final double appTextScale;
  final String? preferredPrinterAddress;

  Locale get locale =>
      language == 'it' ? const Locale('it', 'IT') : const Locale('en', 'GB');

  AppSettings copyWith({
    String? heading,
    String? footer,
    String? logoPath,
    bool clearLogo = false,
    TicketTypography? typography,
    String? language,
    ThemeMode? themeMode,
    double? appTextScale,
    String? preferredPrinterAddress,
    bool clearPreferredPrinter = false,
  }) => AppSettings(
    heading: heading ?? this.heading,
    footer: footer ?? this.footer,
    logoPath: clearLogo ? null : logoPath ?? this.logoPath,
    typography: typography ?? this.typography,
    language: language ?? this.language,
    themeMode: themeMode ?? this.themeMode,
    appTextScale: appTextScale ?? this.appTextScale,
    preferredPrinterAddress: clearPreferredPrinter
        ? null
        : preferredPrinterAddress ?? this.preferredPrinterAddress,
  );

  Map<String, Object?> toJson() => {
    'version': 5,
    'heading': heading,
    'footer': footer,
    'logoPath': logoPath,
    'typography': typography.toJson(),
    'language': language,
    'theme': themeMode.name,
    'appTextScale': appTextScale,
    'preferredPrinterAddress': preferredPrinterAddress,
  };

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    final version = json['version'];
    final footer = version == 1 ? '' : json['footer'];
    final logoPath = version == 1 ? null : json['logoPath'];
    final typographyJson = json['typography'];
    final typography = ![3, 4, 5].contains(version)
        ? const TicketTypography()
        : typographyJson is Map<String, dynamic>
        ? TicketTypography.fromJson(typographyJson)
        : throw const FormatException('Invalid ticket typography');
    final appTextScale = [4, 5].contains(version)
        ? json['appTextScale']
        : defaultAppTextScale;
    final preferredPrinterAddress = version == 5
        ? json['preferredPrinterAddress']
        : null;
    if (![1, 2, 3, 4, 5].contains(version) ||
        json['heading'] is! String ||
        (json['heading'] as String).characters.length > 60 ||
        footer is! String ||
        footer.characters.length > 120 ||
        (logoPath != null && (logoPath is! String || logoPath.length > 2048)) ||
        !['en', 'it'].contains(json['language']) ||
        !ThemeMode.values.any((mode) => mode.name == json['theme']) ||
        appTextScale is! num ||
        !appTextScale.isFinite ||
        appTextScale < minAppTextScale ||
        appTextScale > maxAppTextScale ||
        (preferredPrinterAddress != null &&
            (preferredPrinterAddress is! String ||
                preferredPrinterAddress.isEmpty ||
                preferredPrinterAddress.length > 128))) {
      throw const FormatException('Unsupported or invalid preferences');
    }
    return AppSettings(
      heading: json['heading'] as String,
      footer: footer,
      logoPath: logoPath as String?,
      typography: typography,
      language: json['language'] as String,
      themeMode: ThemeMode.values.byName(json['theme'] as String),
      appTextScale: appTextScale.toDouble(),
      preferredPrinterAddress: preferredPrinterAddress as String?,
    );
  }
}
