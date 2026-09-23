import 'package:flutter/material.dart';

/// Preferences only. Items and ticket data belongs in SQLite.
@immutable
class AppSettings {
  const AppSettings({
    this.heading = '',
    this.footer = '',
    this.logoPath,
    this.language = 'en',
    this.themeMode = ThemeMode.system,
  });

  final String heading;
  final String footer;
  final String? logoPath;
  final String language;
  final ThemeMode themeMode;

  Locale get locale =>
      language == 'it' ? const Locale('it', 'IT') : const Locale('en', 'GB');

  AppSettings copyWith({
    String? heading,
    String? footer,
    String? logoPath,
    bool clearLogo = false,
    String? language,
    ThemeMode? themeMode,
  }) => AppSettings(
    heading: heading ?? this.heading,
    footer: footer ?? this.footer,
    logoPath: clearLogo ? null : logoPath ?? this.logoPath,
    language: language ?? this.language,
    themeMode: themeMode ?? this.themeMode,
  );

  Map<String, Object?> toJson() => {
    'version': 2,
    'heading': heading,
    'footer': footer,
    'logoPath': logoPath,
    'language': language,
    'theme': themeMode.name,
  };

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    final version = json['version'];
    final footer = version == 1 ? '' : json['footer'];
    final logoPath = version == 1 ? null : json['logoPath'];
    if (![1, 2].contains(version) ||
        json['heading'] is! String ||
        (json['heading'] as String).characters.length > 60 ||
        footer is! String ||
        footer.characters.length > 120 ||
        (logoPath != null && (logoPath is! String || logoPath.length > 2048)) ||
        !['en', 'it'].contains(json['language']) ||
        !ThemeMode.values.any((mode) => mode.name == json['theme'])) {
      throw const FormatException('Unsupported or invalid preferences');
    }
    return AppSettings(
      heading: json['heading'] as String,
      footer: footer,
      logoPath: logoPath as String?,
      language: json['language'] as String,
      themeMode: ThemeMode.values.byName(json['theme'] as String),
    );
  }
}
