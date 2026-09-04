import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:open_space_parking/core/providers/core_providers.dart';
import 'package:open_space_parking/core/routes/route_paths.dart';
import 'package:open_space_parking/core/theme/app_spacing.dart';
import 'package:open_space_parking/core/theme/theme_mode_provider.dart';
import 'package:open_space_parking/core/widgets/dialogs/app_dialogs.dart';
import 'package:open_space_parking/features/authentication/presentation/providers/auth_form_providers.dart';
import 'package:open_space_parking/features/authentication/presentation/providers/auth_state_provider.dart';

/// Shared Settings screen: appearance (theme) + logout.
class AccountSettingsPage extends ConsumerStatefulWidget {
  const AccountSettingsPage({super.key});

  @override
  ConsumerState<AccountSettingsPage> createState() =>
      _AccountSettingsPageState();
}

class _AccountSettingsPageState extends ConsumerState<AccountSettingsPage> {
  bool _loggingOut = false;

  static const _themeOptions = <ThemeMode>[
    ThemeMode.light,
    ThemeMode.system,
    ThemeMode.dark,
  ];

  Future<void> _logout() async {
    if (_loggingOut) return;
    final confirmed = await AppDialogs.confirmLogout(context);
    if (!confirmed || !mounted) return;

    setState(() => _loggingOut = true);
    try {
      ref.read(phoneAuthStepProvider.notifier).state = PhoneAuthStep.enterPhone;
      ref.read(verifiedPhoneProvider.notifier).state = null;
      ref.read(authLoadingProvider.notifier).state = false;
      await ref.read(authStateProvider.notifier).logout();
      if (!mounted) return;
      GoRouter.of(context).go(RoutePaths.authEntry);
    } catch (_) {
      if (mounted) {
        ref
            .read(snackbarServiceProvider)
            .showError('Could not log out. Try again.');
      }
    } finally {
      if (mounted) setState(() => _loggingOut = false);
    }
  }

  String _themeLabel(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.dark:
        return 'Dark';
      case ThemeMode.system:
        return 'System';
      case ThemeMode.light:
        return 'Light';
    }
  }

  String _themeSubtitle(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.dark:
        return 'Dark app look';
      case ThemeMode.system:
        return 'Asphalt Pro — dark road brand';
      case ThemeMode.light:
        return 'Bright light app look';
    }
  }

  Future<void> _openAppearanceSheet() async {
    ThemeMode draft = ref.read(themeModeProvider);

    final confirmed = await showModalBottomSheet<ThemeMode>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        final colorScheme = Theme.of(ctx).colorScheme;
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Appearance',
                            style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: colorScheme.onSurface,
                                ),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Close',
                          onPressed: () => Navigator.pop(ctx),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'App look — not your phone theme',
                        style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    for (var i = 0; i < _themeOptions.length; i++) ...[
                      if (i > 0) const Divider(height: 1),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          _themeLabel(_themeOptions[i]),
                          style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                                color: colorScheme.onSurface,
                              ),
                        ),
                        subtitle: Text(
                          _themeSubtitle(_themeOptions[i]),
                          style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                        ),
                        trailing: Radio<ThemeMode>(
                          value: _themeOptions[i],
                          groupValue: draft,
                          activeColor: colorScheme.primary,
                          onChanged: (value) {
                            if (value == null) return;
                            setSheetState(() => draft = value);
                          },
                        ),
                        onTap: () => setSheetState(() => draft = _themeOptions[i]),
                      ),
                    ],
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: FilledButton(
                        onPressed: () => Navigator.pop(ctx, draft),
                        style: FilledButton.styleFrom(
                          backgroundColor: colorScheme.primary,
                          foregroundColor: colorScheme.onPrimary,
                          shape: const StadiumBorder(),
                        ),
                        child: const Text(
                          'Confirm',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (confirmed != null) {
      ref.read(themeModeProvider.notifier).setMode(confirmed);
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              'Preferences',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
          Material(
            color: colorScheme.surface,
            elevation: 1,
            shadowColor: colorScheme.shadow.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(16),
            child: ListTile(
              leading: Icon(
                Icons.palette_outlined,
                color: colorScheme.primary,
              ),
              title: Text(
                'Appearance',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: colorScheme.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
              ),
              subtitle: Text(
                'App look — Light, System, or Dark',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _themeLabel(themeMode),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.chevron_right,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
              onTap: _openAppearanceSheet,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Material(
            color: colorScheme.surface,
            elevation: 1,
            shadowColor: colorScheme.shadow.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(16),
            child: ListTile(
              leading: Icon(Icons.logout, color: colorScheme.error),
              title: Text(
                'Logout',
                style: TextStyle(
                  color: colorScheme.error,
                  fontWeight: FontWeight.w600,
                ),
              ),
              trailing: _loggingOut
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : null,
              onTap: _loggingOut ? null : _logout,
            ),
          ),
        ],
      ),
    );
  }
}
