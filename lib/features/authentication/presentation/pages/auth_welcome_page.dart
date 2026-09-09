import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:open_space_parking/core/routes/route_paths.dart';
import 'package:open_space_parking/core/theme/app_colors.dart';
import 'package:open_space_parking/core/theme/app_spacing.dart';
import 'package:open_space_parking/core/widgets/brand/app_brand_logo.dart';
import 'package:open_space_parking/core/widgets/buttons/primary_button.dart';

/// Production welcome ΓÇö full logo, Find. Park. Go., clear hero (no fake dots/box).
class AuthWelcomePage extends StatefulWidget {
  const AuthWelcomePage({super.key});

  @override
  State<AuthWelcomePage> createState() => _AuthWelcomePageState();
}

class _AuthWelcomePageState extends State<AuthWelcomePage>
    with TickerProviderStateMixin {
  late final AnimationController _enter;
  late final AnimationController _loop;
  late final Animation<double> _logoFade;
  late final Animation<double> _logoScale;
  late final Animation<double> _contentFade;
  late final Animation<Offset> _contentSlide;

  @override
  void initState() {
    super.initState();

    _enter = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _loop = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );

    _logoFade = CurvedAnimation(
      parent: _enter,
      curve: const Interval(0.0, 0.4, curve: Curves.easeOut),
    );
    _logoScale = Tween<double>(begin: 0.86, end: 1).animate(
      CurvedAnimation(
        parent: _enter,
        curve: const Interval(0.0, 0.45, curve: Curves.easeOutCubic),
      ),
    );
    _contentFade = CurvedAnimation(
      parent: _enter,
      curve: const Interval(0.18, 0.7, curve: Curves.easeOut),
    );
    _contentSlide = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _enter,
        curve: const Interval(0.18, 0.75, curve: Curves.easeOutCubic),
      ),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _enter.forward(from: 0);
      _loop.repeat();
    });
  }

  @override
  void dispose() {
    _enter.dispose();
    _loop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isLight = theme.brightness == Brightness.light;

    return Scaffold(
      backgroundColor: isLight ? AppColors.background : colorScheme.surface,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final short = constraints.maxHeight < 700;
            final heroH =
                (constraints.maxHeight * (short ? 0.26 : 0.3)).clamp(150.0, 220.0);
            final logoSize = short ? 104.0 : 120.0;

            return Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(
                    AppSpacing.pagePaddingWide,
                    short ? AppSpacing.md : AppSpacing.lg,
                    AppSpacing.pagePaddingWide,
                    AppSpacing.lg,
                  ),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight -
                          (short ? AppSpacing.md : AppSpacing.lg) -
                          AppSpacing.lg,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        FadeTransition(
                          opacity: _logoFade,
                          child: ScaleTransition(
                            scale: _logoScale,
                            child: Align(
                              child: AppBrandLogo(
                                size: logoSize,
                                showShadow: true,
                              ),
                            ),
                          ),
                        ),
                        SizedBox(height: short ? 14 : 18),
                        FadeTransition(
                          opacity: _contentFade,
                          child: SlideTransition(
                            position: _contentSlide,
                            child: Column(
                              children: [
                                Text(
                                  'OPEN SPACE',
                                  textAlign: TextAlign.center,
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    color: colorScheme.primary,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 1.6,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'PARKING',
                                  textAlign: TextAlign.center,
                                  style:
                                      theme.textTheme.headlineMedium?.copyWith(
                                    color: colorScheme.onSurface,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -0.5,
                                    height: 1.05,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                _FindParkGoTagline(theme: theme),
                                SizedBox(height: short ? 16 : 22),
                                SizedBox(
                                  height: heroH,
                                  width: double.infinity,
                                  child: _WelcomeHeroCard(loop: _loop),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'Verified parking spaces near you',
                                  textAlign: TextAlign.center,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        SizedBox(height: short ? 20 : 26),
                        FadeTransition(
                          opacity: _contentFade,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Semantics(
                                button: true,
                                label: 'Sign in to your account',
                                child: PrimaryButton(
                                  label: 'Sign In',
                                  onPressed: () =>
                                      context.go(RoutePaths.login),
                                ),
                              ),
                              const SizedBox(height: 12),
                              Semantics(
                                button: true,
                                label: 'Create a new account',
                                child: PrimaryButton(
                                  label: 'Create Account',
                                  variant: PrimaryButtonVariant.outlined,
                                  onPressed: () =>
                                      context.go(RoutePaths.register),
                                ),
                              ),
                              const SizedBox(height: 18),
                              Text(
                                'Verified spaces  ┬╖  Secure payments',
                                textAlign: TextAlign.center,
                                style: theme.textTheme.labelMedium?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _FindParkGoTagline extends StatelessWidget {
  const _FindParkGoTagline({required this.theme});

  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final muted = theme.colorScheme.onSurfaceVariant;
    final park = theme.colorScheme.primary;
    final base = theme.textTheme.titleLarge?.copyWith(
      fontWeight: FontWeight.w600,
      height: 1.2,
    );

    return Text.rich(
      TextSpan(
        style: base?.copyWith(color: muted),
        children: [
          const TextSpan(text: 'Find. '),
          TextSpan(
            text: 'Park.',
            style: base?.copyWith(
              color: park,
              fontWeight: FontWeight.w800,
            ),
          ),
          const TextSpan(text: ' Go.'),
        ],
      ),
      textAlign: TextAlign.center,
    );
  }
}

/// Clear hero: map-pin + soft radar rings (no black box, no random dots).
class _WelcomeHeroCard extends StatelessWidget {
  const _WelcomeHeroCard({required this.loop});

  final AnimationController loop;

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isLight
              ? const [Color(0xFFEFF6FF), Color(0xFFF3F8F6)]
              : [
                  scheme.surfaceContainer,
                  scheme.surfaceContainerHigh,
                ],
        ),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: AnimatedBuilder(
        animation: loop,
        builder: (context, _) {
          final t = loop.value;
          return Stack(
            alignment: Alignment.center,
            children: [
              // Soft expanding location rings.
              for (var i = 0; i < 3; i++)
                _RadarRing(
                  progress: (t + i / 3) % 1.0,
                  color: AppColors.navigationBlue,
                ),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.location_on_rounded,
                    size: 52 + (1 - (2 * t - 1).abs()) * 6,
                    color: AppColors.navigationBlue,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Find parking near you',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: scheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Book a verified space in seconds',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _RadarRing extends StatelessWidget {
  const _RadarRing({required this.progress, required this.color});

  final double progress;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final size = 48 + progress * 110;
    final opacity = (1 - progress) * 0.35;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: color.withValues(alpha: opacity),
          width: 2,
        ),
      ),
    );
  }
}
