import 'package:flutter/material.dart';

import 'package:open_space_parking/core/theme/app_spacing.dart';
import 'package:open_space_parking/core/utils/responsive.dart';
import 'package:open_space_parking/core/widgets/brand/app_brand_logo.dart';

enum AuthScaffoldStyle { welcome, form }

class AuthScaffold extends StatelessWidget {
  const AuthScaffold({
    super.key,
    required this.title,
    required this.child,
    this.onBack,
    this.style = AuthScaffoldStyle.form,
    this.subtitle,
  });

  final String title;
  final Widget child;
  final VoidCallback? onBack;
  final AuthScaffoldStyle style;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final maxWidth = context.isDesktop ? 480.0 : 640.0;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: onBack == null
          ? null
          : AppBar(
              elevation: 0,
              backgroundColor: colorScheme.surface,
              foregroundColor: colorScheme.onSurface,
              surfaceTintColor: Colors.transparent,
              iconTheme: IconThemeData(
                color: colorScheme.onSurface,
                size: 24,
              ),
              leading: IconButton(
                tooltip: 'Back',
                onPressed: onBack,
                style: IconButton.styleFrom(
                  foregroundColor: colorScheme.onSurface,
                  backgroundColor: colorScheme.surfaceContainerHighest
                      .withValues(alpha: 0.65),
                ),
                icon: const Icon(Icons.arrow_back_rounded),
              ),
            ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return Align(
              alignment: Alignment.topCenter,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: constraints.maxHeight - AppSpacing.md * 2,
                    maxWidth: maxWidth,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (onBack == null) const SizedBox(height: AppSpacing.lg),
                      _FormHeader(title: title, subtitle: subtitle),
                      const SizedBox(height: AppSpacing.lg),
                      Card(
                        elevation: 0,
                        color: colorScheme.surfaceContainerLowest,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.lg),
                          side: BorderSide(
                            color: colorScheme.outlineVariant
                                .withValues(alpha: 0.8),
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(AppSpacing.cardPaddingWide),
                          child: child,
                        ),
                      ),
                    ],
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

class _FormHeader extends StatelessWidget {
  const _FormHeader({required this.title, this.subtitle});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      children: [
        const AppBrandLogo(size: 56, showShadow: false),
        const SizedBox(height: AppSpacing.md),
        Text(
          title,
          textAlign: TextAlign.center,
          style: theme.textTheme.headlineSmall?.copyWith(
            color: colorScheme.onSurface,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(
            subtitle!,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }
}
