import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:open_space_parking/core/theme/app_spacing.dart';
import 'package:open_space_parking/features/employee/presentation/providers/employee_providers.dart';

/// Employee sub-page layout with title and a Back action on the top right.
class EmployeeSubPageFrame extends ConsumerWidget {
  const EmployeeSubPageFrame({
    super.key,
    required this.title,
    required this.child,
  });

  final String title;
  final Widget child;

  void _goToDashboard(WidgetRef ref) {
    ref.read(employeeShellTabProvider.notifier).state = 0;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.sm,
            AppSpacing.pagePadding,
            AppSpacing.pagePadding,
            AppSpacing.sm,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              IconButton(
                onPressed: () => _goToDashboard(ref),
                icon: const Icon(Icons.arrow_back),
                tooltip: 'Back',
              ),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
            ],
          ),
        ),
        Expanded(child: child),
      ],
    );
  }
}
