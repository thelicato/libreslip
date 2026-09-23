import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/app_settings.dart';

abstract interface class SettingsRepository {
  Future<AppSettings?> load();
  Future<void> save(AppSettings settings);
}

class LocalSettingsRepository implements SettingsRepository {
  LocalSettingsRepository({SharedPreferencesAsync? preferences})
    : _preferences = preferences ?? SharedPreferencesAsync();

  static const storageKey = 'libreslip.preferences';
  final SharedPreferencesAsync _preferences;

  @override
  Future<AppSettings?> load() async {
    final value = await _preferences.getString(storageKey);
    if (value == null) return null;
    final decoded = jsonDecode(value);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Invalid preferences document');
    }
    return AppSettings.fromJson(decoded);
  }

  @override
  Future<void> save(AppSettings settings) {
    // A single versioned document avoids partially updated preference groups.
    AppSettings.fromJson(settings.toJson());
    return _preferences.setString(storageKey, jsonEncode(settings.toJson()));
  }
}
