import 'package:flutter/material.dart';

import '../../printing/domain/ticket_typography.dart';

/// Preferences only. Items and ticket data belongs in SQLite.
@immutable
class AppSettings {
  const AppSettings({
    this.heading = '',
    this.footer = '',
    this.logoPath,
    this.logoWidthPercent = defaultLogoWidthPercent,
    this.typography = const TicketTypography(),
    this.language = 'en',
    this.themeMode = ThemeMode.system,
    this.appTextScale = defaultAppTextScale,
    this.preferredPrinterAddress,
    this.compactCompose = false,
  });

  final String heading;
  final String footer;
  final String? logoPath;
  static const logoWidthOptions = [25, 50, 75, 100];
  static const defaultLogoWidthPercent = 100;
  final int logoWidthPercent;
  final TicketTypography typography;
  static const minAppTextScale = 1.0;
  static const defaultAppTextScale = 1.0;
  static const maxAppTextScale = 1.3;

  final String language;
  final ThemeMode themeMode;
  final double appTextScale;
  final String? preferredPrinterAddress;
  final bool compactCompose;

  Locale get locale =>
      language == 'it' ? const Locale('it', 'IT') : const Locale('en', 'GB');

  AppSettings copyWith({
    String? heading,
    String? footer,
    String? logoPath,
    bool clearLogo = false,
    int? logoWidthPercent,
    TicketTypography? typography,
    String? language,
    ThemeMode? themeMode,
    double? appTextScale,
    String? preferredPrinterAddress,
    bool clearPreferredPrinter = false,
    bool? compactCompose,
  }) => AppSettings(
    heading: heading ?? this.heading,
    footer: footer ?? this.footer,
    logoPath: clearLogo ? null : logoPath ?? this.logoPath,
    logoWidthPercent: logoWidthPercent ?? this.logoWidthPercent,
    typography: typography ?? this.typography,
    language: language ?? this.language,
    themeMode: themeMode ?? this.themeMode,
    appTextScale: appTextScale ?? this.appTextScale,
    preferredPrinterAddress: clearPreferredPrinter
        ? null
        : preferredPrinterAddress ?? this.preferredPrinterAddress,
    compactCompose: compactCompose ?? this.compactCompose,
  );

  Map<String, Object?> toJson() => {
    'version': 7,
    'heading': heading,
    'footer': footer,
    'logoPath': logoPath,
    'logoWidthPercent': logoWidthPercent,
    'typography': typography.toJson(),
    'language': language,
    'theme': themeMode.name,
    'appTextScale': appTextScale,
    'preferredPrinterAddress': preferredPrinterAddress,
    'compactCompose': compactCompose,
  };

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    final version = json['version'];
    final footer = version == 1 ? '' : json['footer'];
    final logoPath = version == 1 ? null : json['logoPath'];
    final typographyJson = json['typography'];
    final typography = ![3, 4, 5, 6, 7].contains(version)
        ? const TicketTypography()
        : typographyJson is Map<String, dynamic>
        ? TicketTypography.fromJson(typographyJson)
        : throw const FormatException('Invalid ticket typography');
    final appTextScale = [4, 5, 6, 7].contains(version)
        ? json['appTextScale']
        : defaultAppTextScale;
    final preferredPrinterAddress = [5, 6, 7].contains(version)
        ? json['preferredPrinterAddress']
        : null;
    final compactCompose = [6, 7].contains(version)
        ? json['compactCompose']
        : false;
    final logoWidthPercent = version == 7
        ? json['logoWidthPercent']
        : defaultLogoWidthPercent;
    if (![1, 2, 3, 4, 5, 6, 7].contains(version) ||
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
        compactCompose is! bool ||
        logoWidthPercent is! int ||
        !logoWidthOptions.contains(logoWidthPercent) ||
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
      logoWidthPercent: logoWidthPercent,
      typography: typography,
      language: json['language'] as String,
      themeMode: ThemeMode.values.byName(json['theme'] as String),
      appTextScale: appTextScale.toDouble(),
      preferredPrinterAddress: preferredPrinterAddress as String?,
      compactCompose: compactCompose,
    );
  }
}
