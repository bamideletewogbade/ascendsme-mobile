import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// ─────────────────────────────────────────────
// Brand color palette — mirrors tokens.jsx
// ─────────────────────────────────────────────
class AppColors {
  // Light surface
  static const Color bgLight = Color(0xFFF2F4F6);
  static const Color bgElevatedLight = Color(0xFFFFFFFF);
  static const Color bgInsetLight = Color(0xFFECEFF2);
  static const Color borderLight = Color(0x14000000);
  static const Color borderStrongLight = Color(0x24000000);
  static const Color textLight = Color(0xFF0F1418);
  static const Color textMutedLight = Color(0xFF5A6470);
  static const Color textFaintLight = Color(0xFF8B95A1);

  // Dark surface
  static const Color bgDark = Color(0xFF0A0F11);
  static const Color bgElevatedDark = Color(0xFF141B1E);
  static const Color bgInsetDark = Color(0xFF1B2326);
  static const Color borderDark = Color(0x12FFFFFF);
  static const Color borderStrongDark = Color(0x24FFFFFF);
  static const Color textDark = Color(0xFFF1F4F6);
  static const Color textMutedDark = Color(0xFF9BA6B0);
  static const Color textFaintDark = Color(0xFF677380);

  // Brand — light
  static const Color teal = Color(0xFF00A99D);
  static const Color tealDeep = Color(0xFF0F8079);
  static const Color tealInk = Color(0xFF024A45);
  static const Color tealSurface = Color(0xFFE6F7F6);
  static const Color tealSurfaceStrong = Color(0xFFC9EEEC);
  static const Color orange = Color(0xFFFF7A00);
  static const Color orangeSurface = Color(0xFFFFF1E2);
  static const Color amber = Color(0xFFF5B021);
  static const Color rose = Color(0xFFE5484D);
  static const Color roseSurface = Color(0xFFFFE9EA);
  static const Color green = Color(0xFF1F9D5C);
  static const Color greenSurface = Color(0xFFE2F5EA);

  // Brand — dark
  static const Color tealDark = Color(0xFF3DC9BC);
  static const Color tealDeepDark = Color(0xFF5FDDD0);
  static const Color tealInkDark = Color(0xFFC8F2EE);
  static const Color tealSurfaceDark = Color(0x1F3DC9BC);
  static const Color tealSurfaceStrongDark = Color(0x383DC9BC);
  static const Color orangeDark = Color(0xFFFF9442);
  static const Color orangeSurfaceDark = Color(0x24FF9442);
  static const Color amberDark = Color(0xFFF9C459);
  static const Color roseDark = Color(0xFFFF6B6F);
  static const Color roseSurfaceDark = Color(0x24FF6B6F);
  static const Color greenDark = Color(0xFF5BC987);
  static const Color greenSurfaceDark = Color(0x245BC987);
}

// ─────────────────────────────────────────────
// ThemeExtension — provides resolved tokens for the current brightness
// ─────────────────────────────────────────────
class AppColorsX extends ThemeExtension<AppColorsX> {
  final bool isDark;
  const AppColorsX({required this.isDark});

  Color get bg => isDark ? AppColors.bgDark : AppColors.bgLight;
  Color get bgElevated => isDark ? AppColors.bgElevatedDark : AppColors.bgElevatedLight;
  Color get bgInset => isDark ? AppColors.bgInsetDark : AppColors.bgInsetLight;
  Color get border => isDark ? AppColors.borderDark : AppColors.borderLight;
  Color get borderStrong => isDark ? AppColors.borderStrongDark : AppColors.borderStrongLight;
  Color get text => isDark ? AppColors.textDark : AppColors.textLight;
  Color get textMuted => isDark ? AppColors.textMutedDark : AppColors.textMutedLight;
  Color get textFaint => isDark ? AppColors.textFaintDark : AppColors.textFaintLight;
  Color get teal => isDark ? AppColors.tealDark : AppColors.teal;
  Color get tealDeep => isDark ? AppColors.tealDeepDark : AppColors.tealDeep;
  Color get tealInk => isDark ? AppColors.tealInkDark : AppColors.tealInk;
  Color get tealSurface => isDark ? AppColors.tealSurfaceDark : AppColors.tealSurface;
  Color get tealSurfaceStrong => isDark ? AppColors.tealSurfaceStrongDark : AppColors.tealSurfaceStrong;
  Color get orange => isDark ? AppColors.orangeDark : AppColors.orange;
  Color get orangeSurface => isDark ? AppColors.orangeSurfaceDark : AppColors.orangeSurface;
  Color get amber => isDark ? AppColors.amberDark : AppColors.amber;
  Color get rose => isDark ? AppColors.roseDark : AppColors.rose;
  Color get roseSurface => isDark ? AppColors.roseSurfaceDark : AppColors.roseSurface;
  Color get green => isDark ? AppColors.greenDark : AppColors.green;
  Color get greenSurface => isDark ? AppColors.greenSurfaceDark : AppColors.greenSurface;
  Color get skeleton => isDark ? const Color(0xFF1F2629) : const Color(0xFFE5E8EB);

  @override
  AppColorsX copyWith({bool? isDark}) =>
      AppColorsX(isDark: isDark ?? this.isDark);

  @override
  AppColorsX lerp(AppColorsX? other, double t) =>
      AppColorsX(isDark: t < 0.5 ? isDark : (other?.isDark ?? isDark));
}

extension AppColorsContext on BuildContext {
  AppColorsX get colors => Theme.of(this).extension<AppColorsX>()!;
  bool get isDark => colors.isDark;
}

// ─────────────────────────────────────────────
// Typography helpers
// ─────────────────────────────────────────────
class AppType {
  static TextStyle display({double size = 44, Color? color}) => GoogleFonts.outfit(
        fontSize: size,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.02 * size,
        color: color,
      );

  static TextStyle heading({double size = 17, Color? color}) => GoogleFonts.outfit(
        fontSize: size,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.01 * size,
        color: color,
      );

  static TextStyle body({double size = 13, FontWeight weight = FontWeight.w400, Color? color}) =>
      GoogleFonts.inter(fontSize: size, fontWeight: weight, color: color);

  static TextStyle mono({double size = 11, Color? color}) => GoogleFonts.jetBrainsMono(
        fontSize: size,
        fontWeight: FontWeight.w500,
        color: color,
      );

  static TextStyle label({double size = 10.5, Color? color}) => GoogleFonts.inter(
        fontSize: size,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.08,
        color: color,
      );
}

// ─────────────────────────────────────────────
// Shadow presets
// ─────────────────────────────────────────────
class AppShadows {
  static const List<BoxShadow> card = [
    BoxShadow(color: Color(0x080F0F0F), blurRadius: 2, offset: Offset(0, 1)),
    BoxShadow(color: Color(0x0F0F0F0F), blurRadius: 14, offset: Offset(0, 4)),
  ];
  static const List<BoxShadow> cardLg = [
    BoxShadow(color: Color(0x100F0F0F), blurRadius: 12, offset: Offset(0, 4)),
    BoxShadow(color: Color(0x1A0F0F0F), blurRadius: 40, offset: Offset(0, 18)),
  ];
  static const List<BoxShadow> sheet = [
    BoxShadow(color: Color(0x2E000000), blurRadius: 40, offset: Offset(0, -16)),
  ];
}

// ─────────────────────────────────────────────
// Material ThemeData
// ─────────────────────────────────────────────
class AppTheme {
  static ThemeData light() => _build(false);
  static ThemeData dark() => _build(true);

  static ThemeData _build(bool dark) {
    final c = AppColorsX(isDark: dark);
    return ThemeData(
      useMaterial3: true,
      brightness: dark ? Brightness.dark : Brightness.light,
      scaffoldBackgroundColor: c.bg,
      colorScheme: ColorScheme(
        brightness: dark ? Brightness.dark : Brightness.light,
        primary: c.teal,
        onPrimary: Colors.white,
        secondary: c.orange,
        onSecondary: Colors.white,
        error: c.rose,
        onError: Colors.white,
        surface: c.bgElevated,
        onSurface: c.text,
      ),
      extensions: [AppColorsX(isDark: dark)],
      textTheme: _textTheme(c.text),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: CupertinoPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
    );
  }

  static TextTheme _textTheme(Color base) {
    return TextTheme(
      displayLarge: AppType.display(size: 52, color: base),
      displayMedium: AppType.display(size: 44, color: base),
      displaySmall: AppType.display(size: 32, color: base),
      headlineLarge: AppType.heading(size: 28, color: base),
      headlineMedium: AppType.heading(size: 22, color: base),
      headlineSmall: AppType.heading(size: 18, color: base),
      titleLarge: AppType.heading(size: 17, color: base),
      titleMedium: AppType.heading(size: 15, color: base),
      titleSmall: AppType.heading(size: 13, color: base),
      bodyLarge: AppType.body(size: 15, color: base),
      bodyMedium: AppType.body(size: 13, color: base),
      bodySmall: AppType.body(size: 11.5, color: base),
      labelLarge: AppType.body(size: 13.5, weight: FontWeight.w600, color: base),
      labelMedium: AppType.body(size: 12, weight: FontWeight.w600, color: base),
      labelSmall: AppType.label(size: 10.5, color: base),
    );
  }
}
