import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// ─────────────────────────────────────────────
// Brand color palette — matches web DESIGN_SYSTEM.md exactly
// Primary Teal:  #009B9E (active states, primary CTAs, focus)
// Secondary Teal: #00A99D (hover states, alternate actions)
// Orange:        #FF7A00 (highlights, warnings, secondary CTAs)
// Text Dark:     #121212 (primary body text)
// Gray scale from web: 50→#F9FAFB, 100→#F3F4F6, 200→#E5E7EB,
// 300→#D1D5DB, 400→#9CA3AF, 500→#6B7280, 900→#111827
// ─────────────────────────────────────────────
class AppColors {
  // Light surface —#122 Gray scale from web DESIGN_SYSTEM.md
  // bg = #FFFFFF (primary backgrounds), surface = #F9FAFB (cards)
  static const Color bgLight = Color(0xFFF9FAFB);       // Gray 50 — secondary bg / cards
  static const Color bgElevatedLight = Color(0xFFFFFFFF); // White — elevated surfaces
  static const Color bgInsetLight = Color(0xFFF3F4F6);   // Gray 100 — inset
  static const Color bgInsetStrongLight = Color(0xFFE5E7EB); // Gray 200 — strong inset
  static const Color borderLight = Color(0xFFE5E7EB);    // Gray 200 — borders
  static const Color borderStrongLight = Color(0xFFD1D5DB); // Gray 300 — strong borders
  static const Color textLight = Color(0xFF121212);      // Near-black primary
  static const Color textMutedLight = Color(0xFF6B7280); // Gray 500 — secondary text
  static const Color textFaintLight = Color(0xFF9CA3AF); // Gray 400 — placeholder/faint

  // Dark surface — adjusted to maintain WCAG contrast on dark backgrounds
  static const Color bgDark = Color(0xFF0A1018);
  static const Color bgElevatedDark = Color(0xFF121A26);
  static const Color bgInsetDark = Color(0xFF1A2230);
  static const Color bgInsetStrongDark = Color(0xFF222C3D);
  static const Color borderDark = Color(0x12FFFFFF);
  static const Color borderStrongDark = Color(0x26FFFFFF);
  static const Color textDark = Color(0xFFF0F4F8);
  static const Color textMutedDark = Color(0xFF9BA6B0);
  static const Color textFaintDark = Color(0xFF6B7785);

  // Brand — light (Teal primary per web DESIGN_SYSTEM.md: #009B9E)
  static const Color teal = Color(0xFF009B9E);           // Web: teal primary
  static const Color tealSecondary = Color(0xFF00A99D);  // Web: teal secondary (hover)
  static const Color tealDeep = Color(0xFF0F8079);
  static const Color tealInk = Color(0xFF024A45);
  static const Color tealTint = Color(0xFF3DBDB3);
  static const Color tealSurface = Color(0xFFE6F7F7);    // Web: Teal Light #E6F7F7
  static const Color tealSurfaceStrong = Color(0xFFC9EEEC);

  // Navy — secondary / dark accent
  static const Color navy = Color(0xFF1A2B48);
  static const Color navyDeep = Color(0xFF031632);
  static const Color navyTint = Color(0xFF374765);
  static const Color navyInk = Color(0xFF0A1830);
  static const Color navySurface = Color(0xFFEBEFF5);
  static const Color navySurfaceStrong = Color(0xFFD5DCEA);

  // Green — positive / success (web badge: bg #ECFDF5, fg #059669)
  static const Color green = Color(0xFF059669);
  static const Color greenDeep = Color(0xFF047857);
  static const Color greenInk = Color(0xFF003316);
  static const Color greenSurface = Color(0xFFECFDF5);
  static const Color greenSurfaceStrong = Color(0xFFC7EDD7);

  // Blue — interactive / links
  static const Color blue = Color(0xFF3498DB);
  static const Color blueDeep = Color(0xFF2474AC);
  static const Color blueSurface = Color(0xFFE5F2FB);
  static const Color blueSurfaceStrong = Color(0xFFC7E4F6);

  // Amber / warning (web badge: bg #FEF3C7, fg #D97706)
  static const Color amber = Color(0xFFD97706);
  static const Color amberSurface = Color(0xFFFEF3C7);
  static const Color amberInk = Color(0xFF7A5800);

  // Rose / error (web error toast: border-left #EF4444)
  static const Color rose = Color(0xFFEF4444);
  static const Color roseSurface = Color(0xFFFFE9EA);
  static const Color roseInk = Color(0xFF7B0F12);

  // Orange — highlights, warnings, secondary CTAs (web: #FF7A00)
  static const Color orange = Color(0xFFFF7A00);
  static const Color orangeSurface = Color(0xFFFFF1E2);

  // Orange — dark (brighter for dark backgrounds, distinct from amber)
  static const Color orangeDark = Color(0xFFFF9442);
  static const Color orangeSurfaceDark = Color(0x24FF9442);

  // Brand — dark (Teal primary — match web light primary luminance)
  static const Color tealDark = Color(0xFF3DC9BC);
  static const Color tealDeepDark = Color(0xFF5FDDD0);
  static const Color tealInkDark = Color(0xFFC8F2EE);
  static const Color tealSurfaceDark = Color(0x1F3DC9BC);
  static const Color tealSurfaceStrongDark = Color(0x383DC9BC);

  // Navy — dark
  static const Color navyDark = Color(0xFF3D5478);
  static const Color navyDeepDark = Color(0xFF1A2B48);
  static const Color navyTintDark = Color(0xFF5D7196);
  static const Color navyInkDark = Color(0xFF091221);
  static const Color navySurfaceDark = Color(0x2E3D5478);
  static const Color navySurfaceStrongDark = Color(0x523D5478);

  // Green — dark
  static const Color greenDarkV2 = Color(0xFF3BD480);
  static const Color greenDeepDark = Color(0xFF28A35F);
  static const Color greenInkDark = Color(0xFF0A2D17);
  static const Color greenSurfaceDark = Color(0x243BD480);
  static const Color greenSurfaceStrongDark = Color(0x423BD480);

  // Blue — dark
  static const Color blueDark = Color(0xFF5DB3F0);
  static const Color blueDeepDark = Color(0xFF3597D8);
  static const Color blueSurfaceDark = Color(0x245DB3F0);
  static const Color blueSurfaceStrongDark = Color(0x425DB3F0);

  // Amber / Rose — dark
  static const Color amberDark = Color(0xFFF9C459);
  static const Color amberSurfaceDark = Color(0x24F5B021);
  static const Color amberInkDark = Color(0xFFF2D27A);
  static const Color roseDark = Color(0xFFFF6F75);
  static const Color roseSurfaceDark = Color(0x29E5484D);
  static const Color roseInkDark = Color(0xFFFFB9BC);
}

// ─────────────────────────────────────────────
// ThemeExtension — provides resolved tokens for the current brightness
// ─────────────────────────────────────────────
class AppColorsX extends ThemeExtension<AppColorsX> {
  final bool isDark;
  const AppColorsX({required this.isDark});

  // ── Surfaces ──
  Color get bg => isDark ? AppColors.bgDark : AppColors.bgLight;
  Color get bgElevated => isDark ? AppColors.bgElevatedDark : AppColors.bgElevatedLight;
  Color get bgInset => isDark ? AppColors.bgInsetDark : AppColors.bgInsetLight;
  Color get bgInsetStrong => isDark ? AppColors.bgInsetStrongDark : AppColors.bgInsetStrongLight;
  Color get border => isDark ? AppColors.borderDark : AppColors.borderLight;
  Color get borderStrong => isDark ? AppColors.borderStrongDark : AppColors.borderStrongLight;
  Color get text => isDark ? AppColors.textDark : AppColors.textLight;
  Color get textMuted => isDark ? AppColors.textMutedDark : AppColors.textMutedLight;
  Color get textFaint => isDark ? AppColors.textFaintDark : AppColors.textFaintLight;

  // ── Teal (primary brand — #009B9E per web DESIGN_SYSTEM.md) ──
  Color get teal => isDark ? AppColors.tealDark : AppColors.teal;
  Color get tealSecondary => isDark ? AppColors.tealDark : AppColors.tealSecondary;
  Color get tealDeep => isDark ? AppColors.tealDeepDark : AppColors.tealDeep;
  Color get tealInk => isDark ? AppColors.tealInkDark : AppColors.tealInk;
  Color get tealTint => isDark ? AppColors.tealDark : AppColors.tealTint;
  Color get tealSurface => isDark ? AppColors.tealSurfaceDark : AppColors.tealSurface;
  Color get tealSurfaceStrong => isDark ? AppColors.tealSurfaceStrongDark : AppColors.tealSurfaceStrong;

  // ── Navy (secondary / dark accent) ──
  Color get navy => isDark ? AppColors.navyDark : AppColors.navy;
  Color get navyDeep => isDark ? AppColors.navyDeepDark : AppColors.navyDeep;
  Color get navyTint => isDark ? AppColors.navyTintDark : AppColors.navyTint;
  Color get navyInk => isDark ? AppColors.navyInkDark : AppColors.navyInk;
  Color get navySurface => isDark ? AppColors.navySurfaceDark : AppColors.navySurface;
  Color get navySurfaceStrong => isDark ? AppColors.navySurfaceStrongDark : AppColors.navySurfaceStrong;

  // ── Green (positive, CTAs) ──
  Color get green => isDark ? AppColors.greenDarkV2 : AppColors.green;
  Color get greenDeep => isDark ? AppColors.greenDeepDark : AppColors.greenDeep;
  Color get greenInk => isDark ? AppColors.greenInkDark : AppColors.greenInk;
  Color get greenSurface => isDark ? AppColors.greenSurfaceDark : AppColors.greenSurface;
  Color get greenSurfaceStrong => isDark ? AppColors.greenSurfaceStrongDark : AppColors.greenSurfaceStrong;

  // ── Blue (interactive, links) ──
  Color get blue => isDark ? AppColors.blueDark : AppColors.blue;
  Color get blueDeep => isDark ? AppColors.blueDeepDark : AppColors.blueDeep;
  Color get blueSurface => isDark ? AppColors.blueSurfaceDark : AppColors.blueSurface;
  Color get blueSurfaceStrong => isDark ? AppColors.blueSurfaceStrongDark : AppColors.blueSurfaceStrong;

  // ── Amber / Rose / Orange ──
  Color get amber => isDark ? AppColors.amberDark : AppColors.amber;
  Color get amberSurface => isDark ? AppColors.amberSurfaceDark : AppColors.amberSurface;
  Color get amberInk => isDark ? AppColors.amberInkDark : AppColors.amberInk;
  Color get rose => isDark ? AppColors.roseDark : AppColors.rose;
  Color get roseSurface => isDark ? AppColors.roseSurfaceDark : AppColors.roseSurface;
  Color get roseInk => isDark ? AppColors.roseInkDark : AppColors.roseInk;
  Color get orange => isDark ? AppColors.orangeDark : AppColors.orange;
  Color get orangeSurface => isDark ? AppColors.orangeSurfaceDark : AppColors.orangeSurface;

  // ── Link text (web: #009B9E) ──
  Color get textLink => AppColors.teal;

  Color get skeleton => isDark ? const Color(0xFF1B2330) : const Color(0xFFE5E8EB);

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
      GoogleFonts.inter(fontSize: size, fontWeight: weight, color: color);  static TextStyle mono({double size = 11, Color? color, FontWeight weight = FontWeight.w500}) =>
      GoogleFonts.jetBrainsMono(
        fontSize: size,
        fontWeight: weight,
        color: color,
      );

  static TextStyle label({double size = 10.5, Color? color, double? letterSpacing}) => GoogleFonts.inter(
        fontSize: size,
        fontWeight: FontWeight.w700,
        letterSpacing: letterSpacing ?? 0.08,
        color: color,
      );
}

// ─────────────────────────────────────────────
// Border radius presets
// ─────────────────────────────────────────────
class AppRadius {
  static const double xs = 6;
  static const double sm = 10;
  static const double md = 14;
  static const double lg = 18;
  static const double xl = 24;
  static const double pill = 999;
}

// ─────────────────────────────────────────────
// Spacing presets (4 px grid)
// ─────────────────────────────────────────────
class AppSpacing {
  static const double xxs = 2;
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double xxxl = 32;
  static const double huge = 40;
}

// ─────────────────────────────────────────────
// Animation presets
// ─────────────────────────────────────────────
class AppAnimation {
  static const Duration fast = Duration(milliseconds: 150);
  static const Duration normal = Duration(milliseconds: 280);
  static const Duration slow = Duration(milliseconds: 400);
  static const Duration page = Duration(milliseconds: 350);
  static const Curve spring = Curves.easeOutCubic;
  static const Curve springBouncy = Curves.easeOutBack;
  static const Curve ease = Curves.easeInOut;
  static const Curve decelerate = Curves.decelerate;
}

// ─────────────────────────────────────────────
// Shadow presets
// ─────────────────────────────────────────────
class AppShadows {
  static const List<BoxShadow> card = [
    BoxShadow(color: Color(0x0A031632), blurRadius: 2, offset: Offset(0, 1)),
    BoxShadow(color: Color(0x0D031632), blurRadius: 24, offset: Offset(0, 8)),
  ];
  static const List<BoxShadow> cardLg = [
    BoxShadow(color: Color(0x0F031632), blurRadius: 12, offset: Offset(0, 4)),
    BoxShadow(color: Color(0x1A031632), blurRadius: 48, offset: Offset(0, 20)),
  ];
  static const List<BoxShadow> navy = [
    BoxShadow(color: Color(0x2E1A2B48), blurRadius: 24, offset: Offset(0, 8)),
    BoxShadow(color: Color(0x1A1A2B48), blurRadius: 48, offset: Offset(0, 20)),
  ];
  static const List<BoxShadow> teal = [
    BoxShadow(color: Color(0x3800A99D), blurRadius: 32, offset: Offset(0, 12)),
  ];
  static const List<BoxShadow> green = [
    BoxShadow(color: Color(0x4D2ECC71), blurRadius: 20, offset: Offset(0, 8)),
  ];
  static const List<BoxShadow> sheet = [
    BoxShadow(color: Color(0x2E031632), blurRadius: 40, offset: Offset(0, -16)),
  ];
  static const List<BoxShadow> elevated = [
    BoxShadow(color: Color(0x0A031632), blurRadius: 4, offset: Offset(0, 2)),
    BoxShadow(color: Color(0x12031632), blurRadius: 16, offset: Offset(0, 6)),
  ];
}

// ─────────────────────────────────────────────
// Gradient presets
// ─────────────────────────────────────────────
class AppGradients {
  static LinearGradient tealToDeep(AppColorsX c) => LinearGradient(
        colors: [c.teal, c.tealDeep],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );

  static LinearGradient tealToGreen(AppColorsX c) => LinearGradient(
        colors: [c.teal, c.greenDeep],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );

  static LinearGradient greenToDeep(AppColorsX c) => LinearGradient(
        colors: [c.green, c.greenDeep],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );

  static LinearGradient navyToDeep(AppColorsX c) => LinearGradient(
        colors: [c.navy, c.navyDeep],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );
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
        secondary: c.green,
        onSecondary: Colors.white,
        tertiary: c.blue,
        onTertiary: Colors.white,
        error: c.rose,
        onError: Colors.white,
        surface: c.bgElevated,
        onSurface: c.text,
        // Explicit link color matching web
        outline: c.border,
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
