import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Ranse brand seed — deep delivery green.
const Color kRanseSeed = Color(0xFF0B6E4F);

ThemeData ranseLightTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: kRanseSeed,
    brightness: Brightness.light,
  );
  return _base(scheme);
}

ThemeData ranseDarkTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: kRanseSeed,
    brightness: Brightness.dark,
  );
  return _base(scheme);
}

ThemeData _base(ColorScheme scheme) => ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 1,
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: scheme.inverseSurface,
        contentTextStyle: TextStyle(color: scheme.onInverseSurface),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        color: scheme.surfaceContainerLow,
      ),
    );

/// Light by default; honours the device scheme only until the user makes an
/// explicit choice, which is then persisted and always wins.
class ThemeController extends ChangeNotifier {
  ThemeController._(this._mode);

  static const _prefKey = 'theme_mode';
  ThemeMode _mode;

  ThemeMode get mode => _mode;

  static Future<ThemeController> load() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_prefKey);
    final mode = switch (stored) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
    return ThemeController._(mode);
  }

  Future<void> setMode(ThemeMode mode) async {
    _mode = mode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    if (mode == ThemeMode.system) {
      await prefs.remove(_prefKey);
    } else {
      await prefs.setString(
          _prefKey, mode == ThemeMode.dark ? 'dark' : 'light');
    }
  }
}
