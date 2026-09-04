import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:open_space_parking/core/theme/app_colors.dart';
import 'package:open_space_parking/core/theme/app_spacing.dart';
import 'package:open_space_parking/core/theme/app_typography.dart';

class AppTheme {
  AppTheme._();

  static const Duration animationDuration = Duration.zero;
  static const Curve animationCurve = Curves.linear;

  static final ThemeData light = _build(
    AppColors.lightScheme,
    scaffoldOverride: AppColors.lightBackground,
    cardOverride: AppColors.lightSurface,
  );

  /// App System theme — Asphalt Pro (does not follow phone theme).
  static final ThemeData system = _build(
    AppColors.systemScheme,
    scaffoldOverride: AppColors.systemBackground,
    cardOverride: AppColors.systemSurface,
  );
  static final ThemeData dark = _build(AppColors.darkScheme);

  static ThemeData _build(
    ColorScheme colorScheme, {
    Color? scaffoldOverride,
    Color? cardOverride,
  }) {
    final isDark = colorScheme.brightness == Brightness.dark;
    final textTheme = AppTypography.textTheme(colorScheme.brightness);
    const buttonRadius = BorderRadius.all(Radius.circular(AppRadius.md));
    final cardRadius = BorderRadius.circular(AppRadius.xl);
    final cardColor = cardOverride ??
        (isDark ? colorScheme.surfaceContainer : AppColors.card);

    return ThemeData(
      useMaterial3: true,
      brightness: colorScheme.brightness,
      colorScheme: colorScheme,
      textTheme: textTheme.apply(
        bodyColor: colorScheme.onSurface,
        displayColor: colorScheme.onSurface,
      ),
      scaffoldBackgroundColor: scaffoldOverride ??
          (isDark ? colorScheme.surface : AppColors.background),
      visualDensity: VisualDensity.standard,
      splashFactory: InkRipple.splashFactory,
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: CupertinoPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor:
            isDark ? colorScheme.surfaceContainer : cardColor,
        foregroundColor: colorScheme.onSurface,
        surfaceTintColor: Colors.transparent,
        systemOverlayStyle: isDark
            ? SystemUiOverlayStyle.light
            : SystemUiOverlayStyle.dark,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          color: colorScheme.onSurface,
          fontWeight: FontWeight.w700,
        ),
        iconTheme: IconThemeData(color: colorScheme.onSurface),
      ),
      cardTheme: CardThemeData(
        elevation: isDark ? 0 : 2,
        shadowColor: AppColors.textPrimary.withValues(alpha: isDark ? 0 : 0.06),
        margin: EdgeInsets.zero,
        color: isDark ? colorScheme.surfaceContainer : cardColor,
        shape: RoundedRectangleBorder(
          borderRadius: cardRadius,
          side: BorderSide(
            color: colorScheme.outlineVariant.withValues(
              alpha: isDark ? 0.35 : 0.7,
            ),
          ),
        ),
        clipBehavior: Clip.antiAlias,
      ),
      dialogTheme: DialogThemeData(
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.xl + 4),
        ),
        backgroundColor: isDark ? colorScheme.surfaceContainerHigh : AppColors.card,
        titleTextStyle: textTheme.titleLarge,
        contentTextStyle: textTheme.bodyMedium,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: isDark ? colorScheme.surfaceContainer : AppColors.card,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      searchBarTheme: SearchBarThemeData(
        backgroundColor: WidgetStatePropertyAll(
          isDark ? colorScheme.surfaceContainerHigh : AppColors.card,
        ),
        elevation: const WidgetStatePropertyAll(2),
        shadowColor: WidgetStatePropertyAll(
          AppColors.textPrimary.withValues(alpha: 0.06),
        ),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            side: BorderSide(color: colorScheme.outlineVariant),
          ),
        ),
        hintStyle: WidgetStatePropertyAll(
          textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
        ),
        textStyle: WidgetStatePropertyAll(
          textTheme.bodyMedium?.copyWith(color: colorScheme.onSurface),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(64, 52),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          backgroundColor:
              isDark ? AppColors.darkPrimary : AppColors.primary,
          foregroundColor: colorScheme.onPrimary,
          elevation: isDark ? 0 : 1,
          shadowColor: AppColors.primary.withValues(alpha: 0.3),
          shape: const RoundedRectangleBorder(borderRadius: buttonRadius),
          textStyle: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(64, 52),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          foregroundColor: colorScheme.onSurface,
          backgroundColor: isDark
              ? colorScheme.surfaceContainerLow
              : colorScheme.surface,
          side: BorderSide(
            color: isDark ? colorScheme.outline : AppColors.primary,
            width: 1.5,
          ),
          shape: const RoundedRectangleBorder(borderRadius: buttonRadius),
          textStyle: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor:
              isDark ? AppColors.darkPrimary : AppColors.primary,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: const RoundedRectangleBorder(borderRadius: buttonRadius),
          textStyle: textTheme.labelLarge?.copyWith(
            color: isDark ? AppColors.darkPrimary : AppColors.primary,
          ),
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          visualDensity: VisualDensity.comfortable,
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.lg),
            ),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark
            ? colorScheme.surfaceContainerHighest.withValues(alpha: 0.55)
            : AppColors.card,
        hintStyle: textTheme.bodyMedium?.copyWith(
          color: colorScheme.onSurfaceVariant,
        ),
        labelStyle: textTheme.bodyMedium?.copyWith(
          color: colorScheme.onSurfaceVariant,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          borderSide: BorderSide(color: colorScheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          borderSide: BorderSide(color: colorScheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          borderSide: const BorderSide(color: AppColors.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          borderSide: const BorderSide(color: AppColors.error, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.md + 2,
        ),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.full),
        ),
        side: BorderSide(color: colorScheme.outlineVariant),
        labelStyle: textTheme.labelMedium,
        backgroundColor: isDark
            ? colorScheme.surfaceContainerHigh
            : AppColors.background,
      ),
      dividerTheme: DividerThemeData(
        color: colorScheme.outlineVariant.withValues(alpha: 0.55),
        space: 1,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        elevation: 4,
        backgroundColor: isDark
            ? colorScheme.inverseSurface
            : AppColors.textPrimary,
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: isDark ? colorScheme.onInverseSurface : Colors.white,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        type: BottomNavigationBarType.fixed,
        backgroundColor: isDark ? colorScheme.surfaceContainer : AppColors.card,
        selectedItemColor:
            isDark ? AppColors.darkPrimary : AppColors.primary,
        unselectedItemColor: colorScheme.onSurfaceVariant,
        elevation: 0,
      ),
      navigationBarTheme: NavigationBarThemeData(
        elevation: 0,
        height: 64,
        backgroundColor: isDark ? colorScheme.surfaceContainer : AppColors.card,
        indicatorColor: isDark
            ? colorScheme.primaryContainer
            : AppColors.brandBlueSoft,
        surfaceTintColor: Colors.transparent,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: isDark ? AppColors.darkPrimary : AppColors.primary,
            );
          }
          return textTheme.labelMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return IconThemeData(
              color: isDark ? AppColors.darkPrimary : AppColors.primary,
              size: 24,
            );
          }
          return IconThemeData(
            color: colorScheme.onSurfaceVariant,
            size: 24,
          );
        }),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        elevation: 3,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(AppRadius.lg)),
        ),
      ),
      listTileTheme: ListTileThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        iconColor: colorScheme.onSurfaceVariant,
        textColor: colorScheme.onSurface,
        titleTextStyle: textTheme.titleMedium?.copyWith(
          color: colorScheme.onSurface,
          fontWeight: FontWeight.w600,
        ),
        subtitleTextStyle: textTheme.bodyMedium?.copyWith(
          color: colorScheme.onSurfaceVariant,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.xs,
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: isDark ? AppColors.darkPrimary : AppColors.primary,
        linearTrackColor: isDark
            ? colorScheme.surfaceContainerHighest
            : const Color(0xFFE8EDF4),
        circularTrackColor: isDark
            ? colorScheme.surfaceContainerHighest
            : const Color(0xFFE8EDF4),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return Colors.white;
          }
          return colorScheme.outline;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.primary;
          }
          return colorScheme.surfaceContainerHighest;
        }),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: isDark ? AppColors.darkPrimary : AppColors.primary,
        unselectedLabelColor: colorScheme.onSurfaceVariant,
        indicatorColor: isDark ? AppColors.darkPrimary : AppColors.primary,
        labelStyle: textTheme.labelLarge,
        unselectedLabelStyle: textTheme.labelMedium,
        dividerColor: colorScheme.outlineVariant.withValues(alpha: 0.4),
      ),
      badgeTheme: const BadgeThemeData(
        backgroundColor: AppColors.available,
        textColor: Colors.white,
      ),
    );
  }
}
