import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:open_space_parking/core/utils/profile_prefill.dart';
import 'package:open_space_parking/features/account/presentation/pages/account_settings_page.dart';
import 'package:open_space_parking/features/account/presentation/widgets/account_menu_view.dart';
import 'package:open_space_parking/features/authentication/presentation/providers/auth_state_provider.dart';
import 'package:open_space_parking/features/land_owner/presentation/pages/land_owner_account_details_page.dart';
import 'package:open_space_parking/features/land_owner/presentation/pages/land_owner_personal_info_page.dart';
import 'package:open_space_parking/features/land_owner/presentation/providers/land_owner_providers.dart';

class LandOwnerProfilePage extends ConsumerWidget {
  const LandOwnerProfilePage({super.key});

  Future<void> _open(BuildContext context, Widget page) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => page),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authStateProvider);
    final ownerId = auth.session?.userId ?? '';
    final profileAsync = ref.watch(landOwnerProfileProvider(ownerId));
    final profile = profileAsync.asData?.value;
    final merged = ProfilePrefill.mergeOwnerDetails(
      saved: profile,
      accountDisplayName: auth.session?.displayName,
      accountEmail: auth.session?.email,
      session: auth.session,
    );
    final subtitle = merged.phone.trim().isNotEmpty
        ? merged.phone
        : (merged.email.trim().isNotEmpty ? merged.email : '');

    return AccountMenuView(
      displayName: merged.fullName,
      subtitle: subtitle,
      items: [
        AccountMenuItem(
          label: 'Personal Info',
          icon: Icons.person_outline,
          onTap: () => _open(context, const LandOwnerPersonalInfoPage()),
        ),
        AccountMenuItem(
          label: 'Account Details',
          icon: Icons.account_balance_wallet_outlined,
          onTap: () => _open(context, const LandOwnerAccountDetailsPage()),
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
