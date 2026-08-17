import 'package:flutter/material.dart';

import 'package:open_space_parking/core/theme/app_spacing.dart';
import 'package:open_space_parking/core/widgets/cards/app_stat_card.dart';

/// Admin dashboard stat tile — delegates to shared [AppStatCard].
class AdminStatCard extends StatelessWidget {
  const AdminStatCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.onTap,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return AppStatCard(
      label: label,
      value: value,
      icon: icon,
      color: color,
      onTap: onTap,
    );
  }
}

class AdminQuickActions extends StatelessWidget {
  const AdminQuickActions({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.md,
      runSpacing: AppSpacing.md,
      children: children,
    );
  }
}
