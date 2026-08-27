import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:open_space_parking/core/common/exceptions/app_exception.dart';
import 'package:open_space_parking/core/providers/core_providers.dart';
import 'package:open_space_parking/core/theme/app_spacing.dart';
import 'package:open_space_parking/core/utils/validators.dart';
import 'package:open_space_parking/core/widgets/buttons/primary_button.dart';
import 'package:open_space_parking/core/widgets/textfields/app_text_field.dart';
import 'package:open_space_parking/core/utils/profile_prefill.dart';
import 'package:open_space_parking/features/authentication/domain/entities/auth_session.dart';
import 'package:open_space_parking/features/authentication/presentation/providers/auth_state_provider.dart';
import 'package:open_space_parking/features/vehicle_owner/domain/entities/vehicle_owner_profile.dart';
import 'package:open_space_parking/features/vehicle_owner/presentation/providers/vehicle_owner_providers.dart';

class VehicleOwnerPersonalInfoPage extends ConsumerStatefulWidget {
  const VehicleOwnerPersonalInfoPage({super.key});

  @override
  ConsumerState<VehicleOwnerPersonalInfoPage> createState() =>
      _VehicleOwnerPersonalInfoPageState();
}

class _VehicleOwnerPersonalInfoPageState
    extends ConsumerState<VehicleOwnerPersonalInfoPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _vehicleController;
  VehicleOwnerProfile? _savedProfile;
  bool _initialized = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _phoneController = TextEditingController();
    _vehicleController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _vehicleController.dispose();
    super.dispose();
  }

  void _fill(VehicleOwnerProfile? profile, AuthSession? session) {
    _savedProfile = profile;
    final merged = ProfilePrefill.mergeVehicleProfile(
      saved: profile,
      accountDisplayName: session?.displayName,
      accountEmail: session?.email,
      session: session,
    );
    if (!_initialized) {
      _nameController.text = merged.fullName;
      _phoneController.text = merged.phone;
      _vehicleController.text = profile?.vehicleNumber?.trim() ?? '';
      _initialized = true;
      return;
    }
    if (_nameController.text.isEmpty) _nameController.text = merged.fullName;
    if (_phoneController.text.isEmpty) _phoneController.text = merged.phone;
    if (_vehicleController.text.isEmpty) {
      _vehicleController.text = profile?.vehicleNumber?.trim() ?? '';
    }
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
              vehicleNumber: _vehicleController.text.trim().isEmpty
                  ? null
                  : _vehicleController.text.trim().toUpperCase(),
              vehicleModel: existing?.vehicleModel,
              vehicleBrand: existing?.vehicleBrand,
              vehicleLengthM: existing?.vehicleLengthM,
              vehicleWidthM: existing?.vehicleWidthM,
              vehicleParkingClass: existing?.vehicleParkingClass,
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
      appBar: AppBar(title: const Text('Personal Info')),
      body: profileAsync.when(
        loading: () {
          _fill(null, auth.session);
          return const Center(child: CircularProgressIndicator());
        },
        error: (_, __) {
          _fill(null, auth.session);
          return _form(vehicleOwnerId, showLoadError: true);
        },
        data: (profile) {
          _fill(profile, auth.session);
          return _form(vehicleOwnerId);
        },
      ),
    );
  }

  Widget _form(String vehicleOwnerId, {bool showLoadError = false}) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            if (showLoadError)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: Text(
                  'Could not refresh profile. You can still save changes.',
                  style: Theme.of(context).textTheme.bodySmall,
                  textAlign: TextAlign.center,
                ),
              ),
            AppTextField(
              controller: _nameController,
              label: 'Full Name',
              validator: (v) => Validators.requiredField(v, fieldName: 'Name'),
            ),
            const SizedBox(height: AppSpacing.md),
            AppTextField(
              controller: _phoneController,
              label: 'Phone number',
              keyboardType: TextInputType.phone,
              validator: (v) => Validators.requiredField(v, fieldName: 'Phone'),
            ),
            const SizedBox(height: AppSpacing.md),
            AppTextField(
              controller: _vehicleController,
              label: 'Vehicle number',
              textCapitalization: TextCapitalization.characters,
              inputFormatters: Validators.vehicleNumberFormatters,
              validator: (v) => Validators.vehicleNumber(v, required: false),
            ),
            const SizedBox(height: AppSpacing.lg),
            PrimaryButton(
              label: 'Save',
              isLoading: _saving,
              onPressed: () => _save(vehicleOwnerId),
            ),
          ],
        ),
      ),
    );
  }
}
