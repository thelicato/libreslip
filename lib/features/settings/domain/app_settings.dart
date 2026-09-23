import 'package:flutter/material.dart';

/// Preferences only. Items and ticket data belongs in SQLite.
@immutable
class AppSettings {
  const AppSettings({
    this.heading = '',
    this.language = 'en',
    this.themeMode = ThemeMode.system,
  });

  final String heading;
  final String language;
  final ThemeMode themeMode;

  Locale get locale =>
      language == 'it' ? const Locale('it', 'IT') : const Locale('en', 'GB');

  AppSettings copyWith({
    String? heading,
    String? language,
    ThemeMode? themeMode,
  }) => AppSettings(
    heading: heading ?? this.heading,
    language: language ?? this.language,
    themeMode: themeMode ?? this.themeMode,
  );

  Map<String, Object> toJson() => {
    'version': 1,
    'heading': heading,
    'language': language,
    'theme': themeMode.name,
  };

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    if (json['version'] != 1 ||
        json['heading'] is! String ||
        (json['heading'] as String).characters.length > 60 ||
        !['en', 'it'].contains(json['language']) ||
        !ThemeMode.values.any((mode) => mode.name == json['theme'])) {
      throw const FormatException('Unsupported or invalid preferences');
    }
    return AppSettings(
      heading: json['heading'] as String,
      language: json['language'] as String,
      themeMode: ThemeMode.values.byName(json['theme'] as String),
    );
  }
}
