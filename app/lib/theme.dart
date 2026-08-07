import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Ranse design system - "the synthesis".
/// Ivory ground, ink-green accent, brass details, Fraunces for brand moments,
/// Archivo for the working UI, frosted glass for floating surfaces.
/// Light is the default face; dark is complete, not an afterthought.
class RanseColors extends ThemeExtension<RanseColors> {
  const RanseColors({
    required this.brass,
    required this.glass,
    required this.glassBorder,
    required this.tagBg,
    required this.tagBrassBg,
    required this.bodyText,
  });

  final Color brass;
  final Color glass;
  final Color glassBorder;
  final Color tagBg;
  final Color tagBrassBg;
  final Color bodyText;

  static const light = RanseColors(
    brass: Color(0xFFA8874C),
    glass: Color(0x9EFFFFFF),
    glassBorder: Color(0xBFFFFFFF),
    tagBg: Color(0xFFEFF4F1),
    tagBrassBg: Color(0xFFF5EFE3),
    bodyText: Color(0xFF33302A),
  );

  static const dark = RanseColors(
    brass: Color(0xFFC2A05E),
    glass: Color(0x99242118),
    glassBorder: Color(0x40FFFFFF),
    tagBg: Color(0xFF25332C),
    tagBrassBg: Color(0xFF352E1E),
    bodyText: Color(0xFFD8D3C8),
  );

  @override
  RanseColors copyWith({
    Color? brass,
    Color? glass,
    Color? glassBorder,
    Color? tagBg,
    Color? tagBrassBg,
    Color? bodyText,
  }) =>
      RanseColors(
        brass: brass ?? this.brass,
        glass: glass ?? this.glass,
        glassBorder: glassBorder ?? this.glassBorder,
        tagBg: tagBg ?? this.tagBg,
        tagBrassBg: tagBrassBg ?? this.tagBrassBg,
        bodyText: bodyText ?? this.bodyText,
      );

  @override
  RanseColors lerp(RanseColors? other, double t) => other == null
      ? this
      : RanseColors(
          brass: Color.lerp(brass, other.brass, t)!,
          glass: Color.lerp(glass, other.glass, t)!,
          glassBorder: Color.lerp(glassBorder, other.glassBorder, t)!,
          tagBg: Color.lerp(tagBg, other.tagBg, t)!,
          tagBrassBg: Color.lerp(tagBrassBg, other.tagBrassBg, t)!,
          bodyText: Color.lerp(bodyText, other.bodyText, t)!,
        );
}

extension RanseContext on BuildContext {
  RanseColors get ranse => Theme.of(this).extension<RanseColors>()!;

  /// Fraunces, for brand moments: wordmark, screen titles, empty states.
  TextStyle disp({double size = 20, FontWeight weight = FontWeight.w600,
      bool italic = false, Color? color}) {
    return GoogleFonts.fraunces(
      fontSize: size,
      fontWeight: weight,
      fontStyle: italic ? FontStyle.italic : FontStyle.normal,
      color: color ?? Theme.of(this).colorScheme.onSurface,
      height: 1.25,
    );
  }
}

const _inkGreen = Color(0xFF175244);

ThemeData ranseLightTheme() => _build(
      brightness: Brightness.light,
      bg: const Color(0xFFF7F4EE),
      surface: Colors.white,
      ink: const Color(0xFF1C1A16),
      dim: const Color(0xFF6E6757),
      line: const Color(0xFFE9E3D6),
      accent: _inkGreen,
      onAccent: const Color(0xFFF3F7F4),
      ranse: RanseColors.light,
    );

ThemeData ranseDarkTheme() => _build(
      brightness: Brightness.dark,
      bg: const Color(0xFF15130E),
      surface: const Color(0xFF1F1C15),
      ink: const Color(0xFFEDE9DF),
      dim: const Color(0xFF9C947F),
      line: const Color(0xFF353122),
      accent: const Color(0xFF4C9B7F),
      onAccent: const Color(0xFF0C1F19),
      ranse: RanseColors.dark,
    );

ThemeData _build({
  required Brightness brightness,
  required Color bg,
  required Color surface,
  required Color ink,
  required Color dim,
  required Color line,
  required Color accent,
  required Color onAccent,
  required RanseColors ranse,
}) {
  final scheme = ColorScheme(
    brightness: brightness,
    primary: accent,
    onPrimary: onAccent,
    secondary: ranse.brass,
    onSecondary: brightness == Brightness.light ? Colors.white : Colors.black,
    error: brightness == Brightness.light
        ? const Color(0xFF9C3838)
        : const Color(0xFFE08A8A),
    onError: Colors.white,
    surface: bg,
    onSurface: ink,
    surfaceContainerLowest: surface,
    surfaceContainerLow: surface,
    surfaceContainer: surface,
    outline: dim,
    outlineVariant: line,
    onSurfaceVariant: dim,
  );

  final text = GoogleFonts.archivoTextTheme(
    brightness == Brightness.light
        ? ThemeData.light().textTheme
        : ThemeData.dark().textTheme,
  ).apply(bodyColor: ink, displayColor: ink);

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: bg,
    textTheme: text,
    dividerColor: line,
    extensions: [ranse],
    appBarTheme: AppBarTheme(
      backgroundColor: bg,
      foregroundColor: ink,
      elevation: 0,
      scrolledUnderElevation: 0,
    ),
    inputDecorationTheme: InputDecorationTheme(
      border: InputBorder.none,
      isDense: true,
      hintStyle: TextStyle(color: dim),
      labelStyle: TextStyle(color: dim),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: ink,
      contentTextStyle: GoogleFonts.archivo(color: bg, fontSize: 13.5),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    listTileTheme: const ListTileThemeData(dense: true),
  );
}

/// Rounded surface card - the workhorse container of the design.
class RanseCard extends StatelessWidget {
  const RanseCard({super.key, required this.child, this.margin, this.padding});

  final Widget child;
  final EdgeInsetsGeometry? margin;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: margin ?? const EdgeInsets.symmetric(horizontal: 14),
      padding: padding,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: scheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }
}

/// Frosted glass container - floating bars, panes, and toolbars.
class Glass extends StatelessWidget {
  const Glass({
    super.key,
    required this.child,
    this.radius = 20,
    this.padding = EdgeInsets.zero,
  });

  final Widget child;
  final double radius;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final ranse = context.ranse;
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: ranse.glass,
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: ranse.glassBorder),
          ),
          child: child,
        ),
      ),
    );
  }
}

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
