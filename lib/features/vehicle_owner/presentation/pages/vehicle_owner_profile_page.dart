import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:open_space_parking/core/common/exceptions/app_exception.dart';
import 'package:open_space_parking/core/providers/core_providers.dart';
import 'package:open_space_parking/core/utils/validators.dart';
import 'package:open_space_parking/core/widgets/buttons/primary_button.dart';
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
  bool _initialized = false;
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
    final merged = ProfilePrefill.mergeVehicleProfile(
      saved: profile,
      accountDisplayName: session?.displayName,
      accountEmail: session?.email,
      session: session,
    );
    if (!_initialized) {
      _nameController.text = merged.fullName;
      _phoneController.text = merged.phone;
      _emailController.text = merged.email;
      _addressController.text = merged.address ?? '';
      _vehicleNumberController.text = merged.vehicleNumber ?? '';
      _vehicleModelController.text = merged.vehicleModel ?? '';
      _initialized = true;
      return;
    }
    if (_nameController.text.isEmpty) _nameController.text = merged.fullName;
    if (_phoneController.text.isEmpty) _phoneController.text = merged.phone;
    if (_emailController.text.isEmpty) _emailController.text = merged.email;
    if (_addressController.text.isEmpty) {
      _addressController.text = merged.address ?? '';
    }
    if (_vehicleNumberController.text.isEmpty) {
      _vehicleNumberController.text = merged.vehicleNumber ?? '';
    }
    if (_vehicleModelController.text.isEmpty) {
      _vehicleModelController.text = merged.vehicleModel ?? '';
    }
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
        actions: const [VehicleOwnerAppBarActions()],
      ),
      body: profileAsync.when(
        loading: () {
          _fill(null, auth.session);
          return const Center(child: CircularProgressIndicator());
        },
        error: (_, __) {
          _fill(null, auth.session);
          return _profileForm(
            context,
            vehicleOwnerId,
            showLoadError: true,
          );
        },
        data: (profile) {
          _fill(profile, auth.session);
          return _profileForm(context, vehicleOwnerId);
        },
      ),
    );
  }

  Widget _profileForm(
    BuildContext context,
    String vehicleOwnerId, {
    bool showLoadError = false,
  }) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
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
              const SizedBox(height: 12),
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
            const SizedBox(height: 24),
            AppTextField(
              controller: _nameController,
              label: 'Full Name',
              validator: (v) => Validators.requiredField(v, fieldName: 'Name'),
            ),
            const SizedBox(height: 12),
            AppTextField(
              controller: _phoneController,
              label: 'Phone',
              keyboardType: TextInputType.phone,
              validator: (v) => Validators.requiredField(v, fieldName: 'Phone'),
            ),
            const SizedBox(height: 12),
            AppTextField(
              controller: _emailController,
              label: 'Email',
              keyboardType: TextInputType.emailAddress,
              validator: Validators.email,
            ),
            const SizedBox(height: 12),
            AppTextField(
              controller: _addressController,
              label: 'Address (optional)',
            ),
            const SizedBox(height: 24),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Default Vehicle',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            const SizedBox(height: 12),
            AppTextField(
              controller: _vehicleNumberController,
              label: 'Vehicle Number',
              hint: 'TN 09 AB 1234',
              textCapitalization: TextCapitalization.characters,
              inputFormatters: Validators.vehicleNumberFormatters,
              validator: (value) =>
                  Validators.vehicleNumber(value, required: false),
            ),
            const SizedBox(height: 12),
            AppTextField(
              controller: _vehicleModelController,
              label: 'Vehicle Model',
            ),
            const SizedBox(height: 24),
            PrimaryButton(
              label: 'Save Profile',
              isLoading: _saving,
              onPressed: () => _save(vehicleOwnerId),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () => ref.read(authStateProvider.notifier).logout(),
              icon: const Icon(Icons.logout),
              label: const Text('Logout'),
            ),
          ],
        ),
      ),
    );
  }
}
