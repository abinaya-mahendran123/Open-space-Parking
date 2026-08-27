import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:open_space_parking/core/theme/app_spacing.dart';
import 'package:open_space_parking/core/utils/profile_prefill.dart';
import 'package:open_space_parking/features/account/presentation/pages/account_settings_page.dart';
import 'package:open_space_parking/features/account/presentation/widgets/account_menu_view.dart';
import 'package:open_space_parking/features/authentication/domain/entities/auth_session.dart';
import 'package:open_space_parking/features/authentication/presentation/providers/auth_state_provider.dart';
import 'package:open_space_parking/features/employee/presentation/providers/employee_providers.dart';

class AdminProfilePage extends ConsumerWidget {
  const AdminProfilePage({super.key});

  Future<void> _open(BuildContext context, Widget page) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => page),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(authStateProvider).session;
    final name = session?.displayName.trim().isNotEmpty == true
        ? session!.displayName
        : 'Admin';
    final email = session?.displayEmail ?? '';
    final phone = session?.phone.trim().isNotEmpty == true
        ? session!.phone.trim()
        : (ProfilePrefill.phoneFromAccount(sessionEmail: session?.email) ?? '');

    return AccountMenuView(
      displayName: name,
      subtitle: phone.isNotEmpty ? phone : email,
      showAppBar: false,
      items: [
        AccountMenuItem(
          label: 'Personal Info',
          icon: Icons.person_outline,
          onTap: () => _open(context, const _SessionPersonalInfoPage()),
        ),
        AccountMenuItem(
          label: 'Settings',
          icon: Icons.settings_outlined,
          onTap: () => _open(context, const AccountSettingsPage()),
        ),
      ],
    );
  }
}

class EmployeeProfilePage extends ConsumerWidget {
  const EmployeeProfilePage({super.key});

  Future<void> _open(BuildContext context, Widget page) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => page),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(authStateProvider).session;
    final name = session?.displayName.trim().isNotEmpty == true
        ? session!.displayName
        : 'Employee';
    final email = session?.displayEmail ?? '';
    final phoneAsync = ref.watch(employeeAssignedPhoneProvider);
    final phone = phoneAsync.valueOrNull?.trim() ?? '';

    return AccountMenuView(
      displayName: name,
      subtitle: phone.isNotEmpty ? phone : email,
      showAppBar: false,
      items: [
        AccountMenuItem(
          label: 'Personal Info',
          icon: Icons.person_outline,
          onTap: () => _open(context, const _EmployeePersonalInfoPage()),
        ),
        AccountMenuItem(
          label: 'Settings',
          icon: Icons.settings_outlined,
          onTap: () => _open(context, const AccountSettingsPage()),
        ),
      ],
    );
  }
}

class SecurityProfilePage extends ConsumerWidget {
  const SecurityProfilePage({super.key});

  Future<void> _open(BuildContext context, Widget page) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => page),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(authStateProvider).session;
    final name = session?.displayName.trim().isNotEmpty == true
        ? session!.displayName
        : 'Security';
    final email = session?.displayEmail ?? '';
    final phone = session?.phone.trim().isNotEmpty == true
        ? session!.phone.trim()
        : (ProfilePrefill.phoneFromAccount(sessionEmail: session?.email) ?? '');

    return AccountMenuView(
      displayName: name,
      subtitle: phone.isNotEmpty ? phone : email,
      items: [
        AccountMenuItem(
          label: 'Personal Info',
          icon: Icons.person_outline,
          onTap: () => _open(context, const _SessionPersonalInfoPage()),
        ),
        AccountMenuItem(
          label: 'Settings',
          icon: Icons.settings_outlined,
          onTap: () => _open(context, const AccountSettingsPage()),
        ),
      ],
    );
  }
}

/// Read-only personal info from the signed-in session (admin / security).
class _SessionPersonalInfoPage extends ConsumerWidget {
  const _SessionPersonalInfoPage();

  String _phoneFor(AuthSession? session) {
    if (session == null) return '';
    final fromPhone = session.phone.trim();
    if (fromPhone.isNotEmpty) return fromPhone;
    return ProfilePrefill.phoneFromAccount(sessionEmail: session.email) ?? '';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(authStateProvider).session;
    final name = session?.displayName.trim() ?? '';
    final email = session?.displayEmail ?? '';
    final phone = _phoneFor(session);
    final colorScheme = Theme.of(context).colorScheme;

    Widget row(String label, String value) {
      return ListTile(
        title: Text(
          label,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
        ),
        subtitle: Text(
          value.isEmpty ? '—' : value,
          style: Theme.of(context).textTheme.titleMedium,
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Personal Info')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          Material(
            color: colorScheme.surface,
            elevation: 1,
            shadowColor: colorScheme.shadow.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(16),
            child: Column(
              children: [
                row('Full Name', name),
                const Divider(height: 1, indent: 16, endIndent: 16),
                row('Phone', phone),
                const Divider(height: 1, indent: 16, endIndent: 16),
                row('Email', email),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Employee personal info — mobile is admin-assigned and not editable.
class _EmployeePersonalInfoPage extends ConsumerWidget {
  const _EmployeePersonalInfoPage();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(authStateProvider).session;
    final name = session?.displayName.trim() ?? '';
    final email = session?.displayEmail ?? '';
    final phoneAsync = ref.watch(employeeAssignedPhoneProvider);
    final phone = phoneAsync.valueOrNull?.trim() ?? '';
    final colorScheme = Theme.of(context).colorScheme;

    Widget row(String label, String value, {String? hint}) {
      return ListTile(
        title: Text(
          label,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value.isEmpty ? '—' : value,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            if (hint != null) ...[
              const SizedBox(height: 4),
              Text(
                hint,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
              ),
            ],
          ],
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Personal Info')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          Material(
            color: colorScheme.surface,
            elevation: 1,
            shadowColor: colorScheme.shadow.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(16),
            child: Column(
              children: [
                row('Full Name', name),
                const Divider(height: 1, indent: 16, endIndent: 16),
                row(
                  'Mobile Number',
                  phone,
                  hint: 'Assigned by admin only',
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
                row('Email', email),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
