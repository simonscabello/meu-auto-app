import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

abstract interface class ThemeModeStore {
  Future<ThemeMode> read();
  Future<void> write(ThemeMode mode);
}

final class SharedPreferencesThemeModeStore implements ThemeModeStore {
  SharedPreferencesThemeModeStore({this.prefs});

  static const key = 'theme_mode';

  final SharedPreferences? prefs;

  Future<SharedPreferences> _prefs() async {
    final injected = prefs;
    if (injected != null) {
      return injected;
    }
    return SharedPreferences.getInstance();
  }

  @override
  Future<ThemeMode> read() async {
    final stored = await _prefs();
    return _decode(stored.getString(key));
  }

  @override
  Future<void> write(ThemeMode mode) async {
    final stored = await _prefs();
    await stored.setString(key, _encode(mode));
  }

  static String _encode(ThemeMode mode) => switch (mode) {
    ThemeMode.light => 'light',
    ThemeMode.dark => 'dark',
    ThemeMode.system => 'system',
  };

  static ThemeMode _decode(String? raw) => switch (raw) {
    'light' => ThemeMode.light,
    'dark' => ThemeMode.dark,
    _ => ThemeMode.system,
  };
}
