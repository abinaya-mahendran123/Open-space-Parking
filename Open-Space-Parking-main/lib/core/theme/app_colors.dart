import 'package:flutter/material.dart';

/// Brand palette for Open Space Parking — deep slate + electric blue + mint.
class AppColors {
  AppColors._();

  // Brand
  static const Color brandBlue = Color(0xFF3B82F6);
  static const Color brandBlueDark = Color(0xFF60A5FA);
  static const Color brandIndigo = Color(0xFF6366F1);
  static const Color brandMint = Color(0xFF10B981);
  static const Color brandViolet = Color(0xFF8B5CF6);
  static const Color brandAmber = Color(0xFFF59E0B);
  static const Color brandCoral = Color(0xFFF97316);

  // Surfaces
  static const Color lightBackground = Color(0xFFF4F7FC);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color darkBackground = Color(0xFF0B1120);
  static const Color darkSurface = Color(0xFF131C31);
  static const Color darkElevated = Color(0xFF1A2744);

  static ColorScheme lightScheme = const ColorScheme(
    brightness: Brightness.light,
    primary: brandBlue,
    onPrimary: Colors.white,
    primaryContainer: Color(0xFFDBEAFE),
    onPrimaryContainer: Color(0xFF1E3A8A),
    secondary: brandMint,
    onSecondary: Colors.white,
    secondaryContainer: Color(0xFFD1FAE5),
    onSecondaryContainer: Color(0xFF065F46),
    tertiary: brandViolet,
    onTertiary: Colors.white,
    tertiaryContainer: Color(0xFFEDE9FE),
    onTertiaryContainer: Color(0xFF4C1D95),
    error: Color(0xFFDC2626),
    onError: Colors.white,
    errorContainer: Color(0xFFFEE2E2),
    onErrorContainer: Color(0xFF991B1B),
    surface: lightBackground,
    onSurface: Color(0xFF0F172A),
    onSurfaceVariant: Color(0xFF475569),
    outline: Color(0xFFCBD5E1),
    outlineVariant: Color(0xFFE2E8F0),
    shadow: Color(0x1A0F172A),
    scrim: Color(0x660F172A),
    inverseSurface: Color(0xFF1E293B),
    onInverseSurface: Color(0xFFF1F5F9),
    inversePrimary: brandBlueDark,
    surfaceTint: brandBlue,
    surfaceContainerHighest: Color(0xFFE2E8F0),
    surfaceContainerHigh: Color(0xFFEEF2F7),
    surfaceContainer: Color(0xFFF8FAFC),
    surfaceContainerLow: lightSurface,
    surfaceContainerLowest: lightSurface,
    surfaceBright: lightSurface,
    surfaceDim: Color(0xFFE8EDF5),
  );

  static ColorScheme darkScheme = const ColorScheme(
    brightness: Brightness.dark,
    primary: brandBlueDark,
    onPrimary: Color(0xFF0B1120),
    primaryContainer: Color(0xFF1E3A8A),
    onPrimaryContainer: Color(0xFFBFDBFE),
    secondary: Color(0xFF34D399),
    onSecondary: Color(0xFF022C22),
    secondaryContainer: Color(0xFF064E3B),
    onSecondaryContainer: Color(0xFFA7F3D0),
    tertiary: Color(0xFFA78BFA),
    onTertiary: Color(0xFF2E1065),
    tertiaryContainer: Color(0xFF4C1D95),
    onTertiaryContainer: Color(0xFFDDD6FE),
    error: Color(0xFFF87171),
    onError: Color(0xFF450A0A),
    errorContainer: Color(0xFF7F1D1D),
    onErrorContainer: Color(0xFFFECACA),
    surface: darkBackground,
    onSurface: Color(0xFFF1F5F9),
    onSurfaceVariant: Color(0xFF94A3B8),
    outline: Color(0xFF334155),
    outlineVariant: Color(0xFF1E293B),
    shadow: Colors.black,
    scrim: Color(0xCC000000),
    inverseSurface: Color(0xFFF1F5F9),
    onInverseSurface: Color(0xFF0F172A),
    inversePrimary: brandBlue,
    surfaceTint: brandBlueDark,
    surfaceContainerHighest: Color(0xFF334155),
    surfaceContainerHigh: darkElevated,
    surfaceContainer: darkSurface,
    surfaceContainerLow: Color(0xFF101827),
    surfaceContainerLowest: Color(0xFF080D18),
    surfaceBright: Color(0xFF243049),
    surfaceDim: Color(0xFF0A101D),
  );

  static LinearGradient backgroundGradient(Brightness brightness) {
    if (brightness == Brightness.dark) {
      return const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFF0B1120),
          Color(0xFF131C31),
          Color(0xFF1A1040),
        ],
        stops: [0.0, 0.55, 1.0],
      );
    }
    return const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Color(0xFFEFF6FF),
        Color(0xFFF4F7FC),
        Color(0xFFECFDF5),
      ],
      stops: [0.0, 0.5, 1.0],
    );
  }

  static LinearGradient brandGradient(Brightness brightness) {
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: brightness == Brightness.dark
          ? const [brandBlueDark, brandIndigo, brandViolet]
          : const [brandBlue, brandIndigo, brandViolet],
    );
  }

  static List<Color> statPalette(Brightness brightness) {
    return brightness == Brightness.dark
        ? const [
            Color(0xFF60A5FA),
            Color(0xFF34D399),
            Color(0xFFFBBF24),
            Color(0xFFA78BFA),
            Color(0xFFF87171),
            Color(0xFF22D3EE),
            Color(0xFFC084FC),
            Color(0xFFFB923C),
          ]
        : const [
            brandBlue,
            brandMint,
            brandAmber,
            brandViolet,
            Color(0xFFDC2626),
            Color(0xFF0891B2),
            Color(0xFF7C3AED),
            brandCoral,
          ];
  }

  static Color success(Brightness brightness) =>
      brightness == Brightness.dark ? const Color(0xFF34D399) : brandMint;

  static Color warning(Brightness brightness) =>
      brightness == Brightness.dark ? const Color(0xFFFBBF24) : brandAmber;

  static Color info(Brightness brightness) =>
      brightness == Brightness.dark ? brandBlueDark : brandBlue;
}
