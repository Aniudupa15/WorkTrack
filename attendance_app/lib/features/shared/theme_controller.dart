import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Holds the user's preferred [ThemeMode] and persists it across launches.
///
/// Defaults to [ThemeMode.system]; the choice is saved to shared_preferences so
/// it survives restarts. `MaterialApp.themeMode` listens to this.
class ThemeController extends ChangeNotifier {
  ThemeController(this._prefs) {
    _mode = _decode(_prefs.getString(_key));
  }

  static const String _key = 'theme_mode';

  final SharedPreferences _prefs;
  ThemeMode _mode = ThemeMode.system;

  ThemeMode get mode => _mode;

  Future<void> setMode(ThemeMode mode) async {
    if (mode == _mode) return;
    _mode = mode;
    notifyListeners();
    await _prefs.setString(_key, mode.name);
  }

  static ThemeMode _decode(String? value) {
    return ThemeMode.values.firstWhere(
      (m) => m.name == value,
      orElse: () => ThemeMode.system,
    );
  }
}
