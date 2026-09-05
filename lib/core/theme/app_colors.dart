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

  // App "System" theme — Option A: Asphalt Pro (dark road brand; never phone theme).
  static const Color systemAsphalt = Color(0xFF263238);
  static const Color systemCard = Color(0xFF37474F);
  static const Color systemRoadBlue = Color(0xFF2196F3);
  static const Color systemLaneWhite = Color(0xFFFFFFFF);
  static const Color systemParkingGreen = Color(0xFF2E7D32);
  static const Color systemWarning = Color(0xFFF9A825);
  static const Color systemDanger = Color(0xFFD32F2F);
  static const Color systemTextMuted = Color(0xFFB0BEC5);
  static const Color systemPrimarySoft = Color(0xFF1565C0);
  static const Color systemPrimaryContainer = Color(0xFF1E4976);
  static const Color systemGreenContainer = Color(0xFF1B5E20);
  static const Color systemWarningContainer = Color(0xFF5D4037);
  static const Color systemDangerContainer = Color(0xFF4E342E);
  static const Color systemBorder = Color(0xFF455A64);
  static const Color systemDivider = Color(0xFF546E7A);
  static const Color systemElevated = Color(0xFF455A64);

  // Aliases for system theme build()
  static const Color systemBackground = systemAsphalt;
  static const Color systemSurface = systemCard;
  static const Color systemPrimary = systemRoadBlue;

  /// Crisp bright Light theme (white + royal blue).
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

  /// Asphalt Pro — dark road-surface brand (distinct from Light & Dark).
  static ColorScheme systemScheme = const ColorScheme(
    brightness: Brightness.dark,
    primary: systemRoadBlue,
    onPrimary: systemLaneWhite,
    primaryContainer: systemPrimaryContainer,
    onPrimaryContainer: Color(0xFFBBDEFB),
    secondary: systemParkingGreen,
    onSecondary: systemLaneWhite,
    secondaryContainer: systemGreenContainer,
    onSecondaryContainer: Color(0xFFC8E6C9),
    tertiary: systemWarning,
    onTertiary: systemAsphalt,
    tertiaryContainer: systemWarningContainer,
    onTertiaryContainer: Color(0xFFFFE082),
    error: systemDanger,
    onError: systemLaneWhite,
    errorContainer: systemDangerContainer,
    onErrorContainer: Color(0xFFFFCDD2),
    surface: systemAsphalt,
    onSurface: systemLaneWhite,
    onSurfaceVariant: systemTextMuted,
    outline: systemBorder,
    outlineVariant: systemDivider,
    shadow: Color(0x40000000),
    scrim: Color(0x99000000),
    inverseSurface: systemLaneWhite,
    onInverseSurface: systemAsphalt,
    inversePrimary: systemPrimarySoft,
    surfaceTint: systemRoadBlue,
    surfaceContainerHighest: systemElevated,
    surfaceContainerHigh: systemCard,
    surfaceContainer: systemCard,
    surfaceContainerLow: Color(0xFF2C393F),
    surfaceContainerLowest: systemAsphalt,
    surfaceBright: systemElevated,
    surfaceDim: Color(0xFF1E272C),
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

  /// Theme-aware foreground / surface tokens (prefer over light-only constants).
  static Color onSurfaceOf(BuildContext context) =>
      Theme.of(context).colorScheme.onSurface;

  static Color onSurfaceVariantOf(BuildContext context) =>
      Theme.of(context).colorScheme.onSurfaceVariant;

  static Color surfaceOf(BuildContext context) =>
      Theme.of(context).colorScheme.surfaceContainerHigh;

  static Color borderOf(BuildContext context) =>
      Theme.of(context).colorScheme.outlineVariant;

  static Color primaryOf(BuildContext context) =>
      Theme.of(context).colorScheme.primary;
}
