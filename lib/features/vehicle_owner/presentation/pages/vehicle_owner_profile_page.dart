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
  late final TextEditingController _emailController;
  late final TextEditingController _addressController;
  late final TextEditingController _vehicleNumberController;
  late final TextEditingController _vehicleModelController;
  bool _editing = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _phoneController = TextEditingController();
    _emailController = TextEditingController();
    _addressController = TextEditingController();
    _vehicleNumberController = TextEditingController();
    _vehicleModelController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    _vehicleNumberController.dispose();
    _vehicleModelController.dispose();
    super.dispose();
  }

  void _fill(VehicleOwnerProfile? profile, AuthSession? session) {
    if (_editing) return;
    final merged = ProfilePrefill.mergeVehicleProfile(
      saved: profile,
      accountDisplayName: session?.displayName,
      accountEmail: session?.email,
      session: session,
    );
    _nameController.text = merged.fullName;
    _phoneController.text = merged.phone;
    _emailController.text = merged.email;
    _addressController.text = merged.address ?? '';
    _vehicleNumberController.text = merged.vehicleNumber ?? '';
    _vehicleModelController.text = merged.vehicleModel ?? '';
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
      await ref.read(vehicleOwnerRepositoryProvider).updateProfile(
            vehicleOwnerId: vehicleOwnerId,
            profile: VehicleOwnerProfile(
              fullName: _nameController.text.trim(),
              phone: _phoneController.text.trim(),
              email: _emailController.text.trim(),
              address: _addressController.text.trim().isEmpty
                  ? null
                  : _addressController.text.trim(),
              vehicleNumber: _vehicleNumberController.text.trim().isEmpty
                  ? null
                  : _vehicleNumberController.text.trim().toUpperCase(),
              vehicleModel: _vehicleModelController.text.trim().isEmpty
                  ? null
                  : _vehicleModelController.text.trim(),
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

  bool get _needsDetails {
    return _emailController.text.trim().isEmpty ||
        _addressController.text.trim().isEmpty;
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
              label: Text(_needsDetails ? 'Add details' : 'Edit'),
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
          return _body(
            context,
            vehicleOwnerId,
          );
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
            'Could not refresh saved profile. You can still add your details.',
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
        const SizedBox(height: AppSpacing.md),
        Text(
          _nameController.text.isEmpty
              ? 'Vehicle owner'
              : _nameController.text,
          style: theme.textTheme.titleLarge,
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
              _detailRow(
                context,
                icon: Icons.email_outlined,
                label: 'Email',
                value: _emailController.text,
                emptyHint: 'Add your email',
              ),
              _detailRow(
                context,
                icon: Icons.home_outlined,
                label: 'Address',
                value: _addressController.text,
                emptyHint: 'Add your address',
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Default vehicle',
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: AppSpacing.sm),
              _detailRow(
                context,
                icon: Icons.directions_car_outlined,
                label: 'Vehicle number',
                value: _vehicleNumberController.text,
                emptyHint: 'Add vehicle number',
              ),
              _detailRow(
                context,
                icon: Icons.directions_car_filled_outlined,
                label: 'Vehicle model',
                value: _vehicleModelController.text,
                emptyHint: 'Add vehicle model',
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        PrimaryButton(
          label: _needsDetails ? 'Add details' : 'Edit details',
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
        hasValue ? value.trim() : emptyHint,
        style: hasValue
            ? null
            : TextStyle(color: Theme.of(context).hintColor),
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
              'Could not refresh saved profile. You can still edit and save.',
              style: Theme.of(context).textTheme.bodySmall,
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
          const SizedBox(height: AppSpacing.md),
          AppTextField(
            controller: _emailController,
            label: 'Email',
            hint: 'name@example.com',
            keyboardType: TextInputType.emailAddress,
            validator: Validators.email,
          ),
          const SizedBox(height: AppSpacing.md),
          AppTextField(
            controller: _addressController,
            label: 'Address',
            hint: 'House, street, area, city',
            keyboardType: TextInputType.streetAddress,
            maxLines: 3,
            validator: (v) =>
                Validators.requiredField(v, fieldName: 'Address'),
          ),
          const SizedBox(height: AppSpacing.lg),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Default Vehicle',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          AppTextField(
            controller: _vehicleNumberController,
            label: 'Vehicle Number',
            hint: 'TN 09 AB 1234',
            textCapitalization: TextCapitalization.characters,
            inputFormatters: Validators.vehicleNumberFormatters,
            validator: (value) =>
                Validators.vehicleNumber(value, required: false),
          ),
          const SizedBox(height: AppSpacing.md),
          AppTextField(
            controller: _vehicleModelController,
            label: 'Vehicle Model',
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
