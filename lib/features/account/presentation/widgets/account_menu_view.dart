import 'package:flutter/material.dart';

import 'package:open_space_parking/core/theme/app_spacing.dart';

class AccountMenuItem {
  const AccountMenuItem({
    required this.label,
    required this.onTap,
    this.icon,
  });

  final String label;
  final VoidCallback onTap;
  final IconData? icon;
}

/// Account hub layout: display-only profile header + list rows.
class AccountMenuView extends StatelessWidget {
  const AccountMenuView({
    super.key,
    required this.displayName,
    required this.subtitle,
    required this.items,
    this.title = 'My Account',
    this.showAppBar = true,
  });

  final String title;
  final String displayName;
  final String subtitle;
  final List<AccountMenuItem> items;
  final bool showAppBar;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final initial = displayName.trim().isNotEmpty
        ? displayName.trim()[0].toUpperCase()
        : '?';

    final body = ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        Material(
          color: colorScheme.surfaceContainerLow,
          elevation: 1,
          shadowColor: colorScheme.shadow.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: colorScheme.primaryContainer,
                  foregroundColor: colorScheme.onPrimaryContainer,
                  child: Text(
                    initial,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        displayName.trim().isEmpty
                            ? 'Your account'
                            : displayName.trim(),
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (subtitle.trim().isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          subtitle.trim(),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Material(
          color: colorScheme.surfaceContainerLow,
          elevation: 1,
          shadowColor: colorScheme.shadow.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(16),
          child: Column(
            children: [
              for (var i = 0; i < items.length; i++) ...[
                if (i > 0) const Divider(height: 1, indent: 16, endIndent: 16),
                ListTile(
                  leading: items[i].icon == null
                      ? null
                      : Icon(items[i].icon),
                  title: Text(items[i].label),
                  trailing: Icon(
                    Icons.chevron_right,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  onTap: items[i].onTap,
                ),
              ],
            ],
          ),
        ),
      ],
    );

    if (!showAppBar) return body;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: Text(title),
        backgroundColor: colorScheme.surfaceContainer,
        surfaceTintColor: Colors.transparent,
      ),
      body: body,
    );
  }
}
