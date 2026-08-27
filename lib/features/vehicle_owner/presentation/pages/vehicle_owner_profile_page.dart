import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:open_space_parking/core/utils/profile_prefill.dart';
import 'package:open_space_parking/features/account/presentation/pages/account_settings_page.dart';
import 'package:open_space_parking/features/account/presentation/widgets/account_menu_view.dart';
import 'package:open_space_parking/features/authentication/presentation/providers/auth_state_provider.dart';
import 'package:open_space_parking/features/vehicle_owner/presentation/pages/vehicle_owner_personal_info_page.dart';
import 'package:open_space_parking/features/vehicle_owner/presentation/providers/vehicle_owner_providers.dart';

class VehicleOwnerProfilePage extends ConsumerWidget {
  const VehicleOwnerProfilePage({super.key});

  Future<void> _open(BuildContext context, Widget page) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => page),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authStateProvider);
    final vehicleOwnerId = auth.session?.userId ?? '';
    final profileAsync = ref.watch(vehicleOwnerProfileProvider(vehicleOwnerId));
    final profile = profileAsync.asData?.value;
    final merged = ProfilePrefill.mergeVehicleProfile(
      saved: profile,
      accountDisplayName: auth.session?.displayName,
      accountEmail: auth.session?.email,
      session: auth.session,
    );
    final subtitle = merged.phone.trim().isNotEmpty
        ? merged.phone
        : (auth.session != null && auth.session!.email.trim().isNotEmpty
            ? auth.session!.email.trim()
            : '');

    return AccountMenuView(
      displayName: merged.fullName,
      subtitle: subtitle,
      items: [
        AccountMenuItem(
          label: 'Personal Info',
          icon: Icons.person_outline,
          onTap: () => _open(context, const VehicleOwnerPersonalInfoPage()),
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
