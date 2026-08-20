import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:open_space_parking/core/common/exceptions/app_exception.dart';
import 'package:open_space_parking/core/providers/core_providers.dart';
import 'package:open_space_parking/core/theme/app_spacing.dart';
import 'package:open_space_parking/core/utils/validators.dart';
import 'package:open_space_parking/core/widgets/buttons/primary_button.dart';
import 'package:open_space_parking/core/widgets/cards/app_card.dart';
import 'package:open_space_parking/core/widgets/textfields/app_text_field.dart';
import 'package:open_space_parking/core/utils/profile_prefill.dart';
import 'package:open_space_parking/features/authentication/domain/entities/auth_session.dart';
import 'package:open_space_parking/features/authentication/presentation/providers/auth_state_provider.dart';
import 'package:open_space_parking/features/vehicle_owner/domain/entities/vehicle_owner_profile.dart';
import 'package:open_space_parking/features/vehicle_owner/presentation/providers/vehicle_owner_providers.dart';
import 'package:open_space_parking/features/vehicle_owner/presentation/widgets/vehicle_owner_app_bar_actions.dart';

class VehicleOwnerProfilePage extends ConsumerStatefulWidget {
  const VehicleOwnerProfilePage({super.key});

  @override
  ConsumerState<VehicleOwnerProfilePage> createState() =>
      _VehicleOwnerProfilePageState();
}

class _VehicleOwnerProfilePageState extends ConsumerState<VehicleOwnerProfilePage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  VehicleOwnerProfile? _savedProfile;
  bool _editing = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _phoneController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  void _fill(VehicleOwnerProfile? profile, AuthSession? session) {
    if (_editing) return;
    _savedProfile = profile;
    final merged = ProfilePrefill.mergeVehicleProfile(
      saved: profile,
      accountDisplayName: session?.displayName,
      accountEmail: session?.email,
      session: session,
    );
    _nameController.text = merged.fullName;
    _phoneController.text = merged.phone;
  }

  void _startEditing() {
    setState(() => _editing = true);
  }

  void _cancelEditing(VehicleOwnerProfile? profile, AuthSession? session) {
    setState(() => _editing = false);
    _fill(profile, session);
  }

  Future<void> _save(String vehicleOwnerId) async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);
    try {
      final existing = _savedProfile;
      await ref.read(vehicleOwnerRepositoryProvider).updateProfile(
            vehicleOwnerId: vehicleOwnerId,
            profile: VehicleOwnerProfile(
              fullName: _nameController.text.trim(),
              phone: _phoneController.text.trim(),
              // Keep previously stored vehicle fields; only name/phone are edited.
              vehicleNumber: existing?.vehicleNumber,
              vehicleModel: existing?.vehicleModel,
              vehicleBrand: existing?.vehicleBrand,
              vehicleLengthM: existing?.vehicleLengthM,
              vehicleWidthM: existing?.vehicleWidthM,
              vehicleParkingClass: existing?.vehicleParkingClass,
            ),
          );
      ref.invalidate(vehicleOwnerProfileProvider(vehicleOwnerId));
      if (mounted) setState(() => _editing = false);
      ref.read(snackbarServiceProvider).showSuccess('Profile updated.');
    } on AppException catch (e) {
      ref.read(snackbarServiceProvider).showError(e.message);
    } catch (_) {
      ref.read(snackbarServiceProvider).showError('Could not update profile.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authStateProvider);
    final vehicleOwnerId = auth.session?.userId ?? '';
    final profileAsync = ref.watch(vehicleOwnerProfileProvider(vehicleOwnerId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          if (_editing)
            TextButton(
              onPressed: _saving
                  ? null
                  : () => _cancelEditing(
                        profileAsync.asData?.value,
                        auth.session,
                      ),
              child: const Text('Cancel'),
            )
          else
            TextButton.icon(
              onPressed: _startEditing,
              icon: const Icon(Icons.edit_outlined),
              label: const Text('Edit'),
            ),
          const VehicleOwnerAppBarActions(),
        ],
      ),
      body: profileAsync.when(
        loading: () {
          _fill(null, auth.session);
          return const Center(child: CircularProgressIndicator());
        },
        error: (_, __) {
          _fill(null, auth.session);
          return _body(
            context,
            vehicleOwnerId,
            showLoadError: true,
          );
        },
        data: (profile) {
          _fill(profile, auth.session);
          return _body(context, vehicleOwnerId);
        },
      ),
    );
  }

  Widget _body(
    BuildContext context,
    String vehicleOwnerId, {
    bool showLoadError = false,
  }) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.pagePadding),
      child: _editing
          ? _profileForm(context, vehicleOwnerId, showLoadError: showLoadError)
          : _profileView(
              context,
              vehicleOwnerId,
              showLoadError: showLoadError,
            ),
    );
  }

  Widget _profileView(
    BuildContext context,
    String vehicleOwnerId, {
    bool showLoadError = false,
  }) {
    final theme = Theme.of(context);
    final initial = (_nameController.text.isNotEmpty
            ? _nameController.text[0]
            : 'V')
        .toUpperCase();

    return Column(
      children: [
        if (showLoadError) ...[
          Text(
            'Could not refresh saved profile. You can still edit your details.',
            style: theme.textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
          TextButton(
            onPressed: () =>
                ref.invalidate(vehicleOwnerProfileProvider(vehicleOwnerId)),
            child: const Text('Retry'),
          ),
          const SizedBox(height: AppSpacing.md),
        ],
        CircleAvatar(
          radius: 40,
          child: Text(initial, style: const TextStyle(fontSize: 32)),
        ),
        const SizedBox(height: AppSpacing.lg),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Vehicle owner details',
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: AppSpacing.sm),
              _detailRow(
                context,
                icon: Icons.person_outline,
                label: 'Full name',
                value: _nameController.text,
              ),
              _detailRow(
                context,
                icon: Icons.phone_outlined,
                label: 'Phone',
                value: _phoneController.text,
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        PrimaryButton(
          label: 'Edit details',
          icon: Icons.edit_outlined,
          onPressed: _startEditing,
        ),
        const SizedBox(height: AppSpacing.md),
        OutlinedButton.icon(
          onPressed: () => ref.read(authStateProvider.notifier).logout(),
          icon: const Icon(Icons.logout),
          label: const Text('Logout'),
        ),
      ],
    );
  }

  Widget _detailRow(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
    String emptyHint = 'Not added',
  }) {
    final hasValue = value.trim().isNotEmpty;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon),
      title: Text(label),
      subtitle: Text(
        hasValue ? value : emptyHint,
        style: TextStyle(
          color: hasValue
              ? null
              : Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }

  Widget _profileForm(
    BuildContext context,
    String vehicleOwnerId, {
    bool showLoadError = false,
  }) {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          if (showLoadError) ...[
            Text(
              'Could not refresh saved profile. You can still edit your details.',
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.md),
          ],
          CircleAvatar(
            radius: 40,
            child: Text(
              (_nameController.text.isNotEmpty
                      ? _nameController.text[0]
                      : 'V')
                  .toUpperCase(),
              style: const TextStyle(fontSize: 32),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          AppTextField(
            controller: _nameController,
            label: 'Full Name',
            validator: (v) => Validators.requiredField(v, fieldName: 'Name'),
          ),
          const SizedBox(height: AppSpacing.md),
          AppTextField(
            controller: _phoneController,
            label: 'Phone',
            keyboardType: TextInputType.phone,
            validator: (v) => Validators.requiredField(v, fieldName: 'Phone'),
          ),
          const SizedBox(height: AppSpacing.lg),
          PrimaryButton(
            label: 'Save details',
            isLoading: _saving,
            onPressed: () => _save(vehicleOwnerId),
          ),
        ],
      ),
    );
  }
}
