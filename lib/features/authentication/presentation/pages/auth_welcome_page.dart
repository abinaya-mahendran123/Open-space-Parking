import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:open_space_parking/core/routes/route_paths.dart';
import 'package:open_space_parking/core/theme/app_spacing.dart';
import 'package:open_space_parking/core/widgets/brand/app_brand_logo.dart';
import 'package:open_space_parking/core/widgets/buttons/primary_button.dart';

/// Welcome — portrait art (no baked-in buttons) + real Sign In / Create Account.
class AuthWelcomePage extends StatelessWidget {
  const AuthWelcomePage({super.key});

  /// Cropped from welcome_portrait.jpg — logo, tagline, car only (no buttons).
  static const _portraitAsset = 'assets/images/welcome_portrait_nobuttons.jpg';

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.sm,
            AppSpacing.md,
            AppSpacing.lg,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: ColoredBox(
                    color: colorScheme.surface,
                    child: Image.asset(
                      _portraitAsset,
                      fit: BoxFit.cover,
                      alignment: Alignment.topCenter,
                      width: double.infinity,
                      height: double.infinity,
                      filterQuality: FilterQuality.high,
                      errorBuilder: (_, __, ___) => const _PortraitFallback(),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Semantics(
                button: true,
                label: 'Sign in to your account',
                child: PrimaryButton(
                  label: 'Sign In',
                  onPressed: () => context.go(RoutePaths.login),
                ),
              ),
              const SizedBox(height: 12),
              Semantics(
                button: true,
                label: 'Create a new account',
                child: PrimaryButton(
                  label: 'Create Account',
                  variant: PrimaryButtonVariant.outlined,
                  onPressed: () => context.go(RoutePaths.register),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PortraitFallback extends StatelessWidget {
  const _PortraitFallback();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return ColoredBox(
          color: Theme.of(context).colorScheme.surface,
          child: Center(
            child: OpenSkyHeroIllustration(
              height: constraints.maxHeight * 0.55,
            ),
          ),
        );
      },
    );
  }
}
