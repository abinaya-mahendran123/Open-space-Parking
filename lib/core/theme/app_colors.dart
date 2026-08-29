import 'package:flutter/material.dart';

/// Open Sky + Map-First — centralized design tokens.
class AppColors {
  AppColors._();

  // ── Light mode ─────────────────────────────────────────────────────────────
  static const Color background = Color(0xFFF7F9FC);
  static const Color primary = Color(0xFF2563EB);
  static const Color primaryDark = Color(0xFF1D4ED8);

  static const Color available = Color(0xFF16A34A);
  static const Color availableLight = Color(0xFFDCFCE7);

  static const Color limited = Color(0xFFF59E0B);
  static const Color limitedLight = Color(0xFFFEF3C7);

  static const Color full = Color(0xFFDC2626);
  static const Color fullLight = Color(0xFFFEE2E2);

  static const Color textPrimary = Color(0xFF111827);
  static const Color textSecondary = Color(0xFF64748B);
  static const Color textMuted = Color(0xFF94A3B8);

  static const Color surface = Color(0xFFFFFFFF);
  static const Color border = Color(0xFFE2E8F0);
  static const Color divider = Color(0xFFE5E7EB);

  // ── Dark mode ──────────────────────────────────────────────────────────────
  static const Color darkBackground = Color(0xFF0F1419);
  static const Color darkSurface = Color(0xFF1A2332);
  static const Color darkPrimary = Color(0xFF5B9CF6);
  static const Color darkText = Color(0xFFF8FAFC);
  static const Color darkTextSecondary = Color(0xFF94A3B8);
  static const Color darkElevated = Color(0xFF243044);

  // ── Aliases (backward compatible) ──────────────────────────────────────────
  static const Color brandBlue = primary;
  static const Color brandBlueLight = darkPrimary;
  static const Color brandBlueDark = primaryDark;
  static const Color brandBlueSoft = Color(0xFFDBEAFE);
  static const Color brandMint = available;
  static const Color brandMintLight = Color(0xFF22C55E);
  static const Color brandMintSoft = availableLight;
  static const Color brandAmber = limited;
  static const Color brandCoral = Color(0xFFEF4444);
  static const Color lightSurface = surface;
  static const Color card = surface;
  static const Color error = full;
  static const Color warning = limited;
  static const Color availableHigh = available;
  static const Color availableMedium = limited;
  static const Color availableNone = full;

  // App "System" theme — branded Open Sky (always light; never phone theme).
  static const Color systemBackground = background; // #F7F9FC
  static const Color systemSurface = surface;
  static const Color systemPrimary = primary;

  /// Crisp bright Light theme (distinct from System Open Sky).
  static const Color lightBackground = Color(0xFFFAFBFD);
  static const Color lightPrimary = Color(0xFF1D4ED8);

  static ColorScheme lightScheme = const ColorScheme(
    brightness: Brightness.light,
    primary: lightPrimary,
    onPrimary: Colors.white,
    primaryContainer: Color(0xFFE0E7FF),
    onPrimaryContainer: Color(0xFF1E3A8A),
    secondary: available,
    onSecondary: Colors.white,
    secondaryContainer: availableLight,
    onSecondaryContainer: Color(0xFF14532D),
    tertiary: Color(0xFF0284C7),
    onTertiary: Colors.white,
    tertiaryContainer: Color(0xFFE0F2FE),
    onTertiaryContainer: Color(0xFF0C4A6E),
    error: full,
    onError: Colors.white,
    errorContainer: fullLight,
    onErrorContainer: Color(0xFF991B1B),
    surface: lightBackground,
    onSurface: textPrimary,
    onSurfaceVariant: textSecondary,
    outline: Color(0xFFD0D7E2),
    outlineVariant: Color(0xFFE8ECF2),
    shadow: Color(0x14111827),
    scrim: Color(0x66111827),
    inverseSurface: Color(0xFF1E293B),
    onInverseSurface: darkText,
    inversePrimary: darkPrimary,
    surfaceTint: lightPrimary,
    surfaceContainerHighest: Color(0xFFE4EAF3),
    surfaceContainerHigh: Color(0xFFEEF2F8),
    surfaceContainer: surface,
    surfaceContainerLow: surface,
    surfaceContainerLowest: surface,
    surfaceBright: surface,
    surfaceDim: Color(0xFFE4EAF3),
  );

  /// App System look — soft Open Sky blue-gray; does not follow phone dark mode.
  static ColorScheme systemScheme = const ColorScheme(
    brightness: Brightness.light,
    primary: primary,
    onPrimary: Colors.white,
    primaryContainer: brandBlueSoft,
    onPrimaryContainer: Color(0xFF1E3A8A),
    secondary: available,
    onSecondary: Colors.white,
    secondaryContainer: availableLight,
    onSecondaryContainer: Color(0xFF14532D),
    tertiary: Color(0xFF0EA5E9),
    onTertiary: Colors.white,
    tertiaryContainer: Color(0xFFE0F2FE),
    onTertiaryContainer: Color(0xFF0C4A6E),
    error: full,
    onError: Colors.white,
    errorContainer: fullLight,
    onErrorContainer: Color(0xFF991B1B),
    surface: systemBackground,
    onSurface: textPrimary,
    onSurfaceVariant: textSecondary,
    outline: border,
    outlineVariant: divider,
    shadow: Color(0x14111827),
    scrim: Color(0x66111827),
    inverseSurface: Color(0xFF1E293B),
    onInverseSurface: darkText,
    inversePrimary: darkPrimary,
    surfaceTint: primary,
    surfaceContainerHighest: Color(0xFFE8EDF4),
    surfaceContainerHigh: Color(0xFFF1F5F9),
    surfaceContainer: systemSurface,
    surfaceContainerLow: systemSurface,
    surfaceContainerLowest: systemSurface,
    surfaceBright: systemSurface,
    surfaceDim: Color(0xFFE8EDF5),
  );

  static ColorScheme darkScheme = const ColorScheme(
    brightness: Brightness.dark,
    primary: darkPrimary,
    onPrimary: darkBackground,
    primaryContainer: Color(0xFF1E3A8A),
    onPrimaryContainer: Color(0xFFBFDBFE),
    secondary: brandMintLight,
    onSecondary: Color(0xFF052E16),
    secondaryContainer: Color(0xFF14532D),
    onSecondaryContainer: Color(0xFFBBF7D0),
    tertiary: Color(0xFF38BDF8),
    onTertiary: Color(0xFF0C4A6E),
    tertiaryContainer: Color(0xFF0C4A6E),
    onTertiaryContainer: Color(0xFFBAE6FD),
    error: Color(0xFFF87171),
    onError: Color(0xFF450A0A),
    errorContainer: Color(0xFF7F1D1D),
    onErrorContainer: Color(0xFFFECACA),
    surface: darkBackground,
    onSurface: darkText,
    onSurfaceVariant: darkTextSecondary,
    outline: Color(0xFF334155),
    outlineVariant: Color(0xFF1E293B),
    shadow: Colors.black,
    scrim: Color(0xCC000000),
    inverseSurface: darkText,
    onInverseSurface: textPrimary,
    inversePrimary: primary,
    surfaceTint: darkPrimary,
    surfaceContainerHighest: Color(0xFF334155),
    surfaceContainerHigh: darkElevated,
    surfaceContainer: darkSurface,
    surfaceContainerLow: Color(0xFF141C28),
    surfaceContainerLowest: Color(0xFF0A0F14),
    surfaceBright: Color(0xFF243049),
    surfaceDim: Color(0xFF0A1018),
  );

  // ── Availability helpers ───────────────────────────────────────────────────

  /// 0 = full, 1 = limited (≤50%), 2 = available (>50%)
  static int availabilityTier(int freeSlots, int totalSlots) {
    if (freeSlots <= 0) return 0;
    if (totalSlots <= 0) return 2;
    final ratio = freeSlots / totalSlots;
    return ratio > 0.5 ? 2 : 1;
  }

  static Color availabilityColorForTier(int tier) {
    switch (tier) {
      case 2:
        return available;
      case 1:
        return limited;
      default:
        return full;
    }
  }

  static Color availabilityBackgroundForTier(int tier, [Brightness? brightness]) {
    final isDark = brightness == Brightness.dark;
    switch (tier) {
      case 2:
        return isDark ? const Color(0xFF14532D) : availableLight;
      case 1:
        return isDark ? const Color(0xFF78350F) : limitedLight;
      default:
        return isDark ? const Color(0xFF7F1D1D) : fullLight;
    }
  }

  static String availabilityLabel(int freeSlots, int totalSlots) {
    if (freeSlots <= 0) return 'Full';
    if (totalSlots > 0) {
      return '$freeSlots / $totalSlots spots available';
    }
    return '$freeSlots spots available';
  }

  static String availabilityShortLabel(int freeSlots, int totalSlots) {
    if (freeSlots <= 0) return 'Full';
    final tier = availabilityTier(freeSlots, totalSlots);
    if (tier == 2) return '$freeSlots spots available';
    return '$freeSlots spots left';
  }

  static double googleMarkerHueForTier(int tier, {bool selected = false}) {
    if (selected) return 210; // blue — user's selection
    switch (tier) {
      case 2:
        return 120; // green
      case 1:
        return 30; // orange
      default:
        return 0; // red
    }
  }

  static Color osmMarkerColorForTier(int tier, {bool selected = false}) {
    if (selected) return primary;
    return availabilityColorForTier(tier);
  }

  // ── Charts (blue, green, orange only) ──────────────────────────────────────
  static List<Color> statPalette(Brightness brightness) {
    if (brightness == Brightness.dark) {
      return const [
        darkPrimary,
        brandMintLight,
        limited,
        Color(0xFF38BDF8),
        brandMintLight,
        limited,
        darkPrimary,
        Color(0xFF38BDF8),
      ];
    }
    return const [
      primary,
      available,
      limited,
      primaryDark,
      available,
      limited,
      Color(0xFF0891B2),
      primaryDark,
    ];
  }

  static Color success(Brightness brightness) =>
      brightness == Brightness.dark ? brandMintLight : available;

  static Color warningColor(Brightness brightness) =>
      brightness == Brightness.dark ? const Color(0xFFFBBF24) : limited;

  static Color info(Brightness brightness) =>
      brightness == Brightness.dark ? darkPrimary : primary;
}
