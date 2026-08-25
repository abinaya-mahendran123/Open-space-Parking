import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:open_space_parking/core/common/exceptions/app_exception.dart';
import 'package:open_space_parking/core/providers/core_providers.dart';
import 'package:open_space_parking/core/routes/app_router.dart';
import 'package:open_space_parking/core/routes/route_paths.dart';
import 'package:open_space_parking/core/theme/app_spacing.dart';
import 'package:open_space_parking/core/utils/validators.dart';
import 'package:open_space_parking/core/widgets/buttons/primary_button.dart';
import 'package:open_space_parking/core/widgets/cards/app_card.dart';
import 'package:open_space_parking/core/widgets/textfields/app_text_field.dart';
import 'package:open_space_parking/core/utils/profile_prefill.dart';
import 'package:open_space_parking/features/authentication/domain/entities/auth_session.dart';
import 'package:open_space_parking/features/authentication/presentation/providers/auth_form_providers.dart';
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
  late final TextEditingController _vehicleController;
  VehicleOwnerProfile? _savedProfile;
  bool _editing = false;
  bool _saving = false;
  bool _loggingOut = false;

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
    _vehicleController.text = profile?.vehicleNumber?.trim() ?? '';
  }

  void _startEditing() => setState(() => _editing = true);

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

  void _clearAuthFormState() {
    ref.read(phoneAuthStepProvider.notifier).state = PhoneAuthStep.enterPhone;
    ref.read(verifiedPhoneProvider.notifier).state = null;
    ref.read(authLoadingProvider.notifier).state = false;
  }

  Future<void> _logout() async {
    if (_loggingOut) return;

    setState(() {
      _loggingOut = true;
      _editing = false;
    });

    _clearAuthFormState();
    await ref.read(authStateProvider.notifier).logout();
    if (!mounted) return;

    ref.read(appRouterProvider).go(RoutePaths.authEntry);
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authStateProvider);
    final vehicleOwnerId = auth.session?.userId ?? '';
    final profileAsync = ref.watch(vehicleOwnerProfileProvider(vehicleOwnerId));

    ref.listen<AuthState>(authStateProvider, (previous, next) {
      if (previous?.status == AuthStatus.authenticated &&
          next.status == AuthStatus.unauthenticated &&
          mounted) {
        ref.read(appRouterProvider).go(RoutePaths.authEntry);
      }
    });

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
          return _body(context, vehicleOwnerId, showLoadError: true);
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
      padding: const EdgeInsets.all(AppSpacing.md),
      child: _editing
          ? _profileForm(context, vehicleOwnerId, showLoadError: showLoadError)
          : _profileView(showLoadError: showLoadError),
    );
  }

  Widget _profileView({bool showLoadError = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showLoadError)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: Text(
              'Could not refresh profile. Showing saved details.',
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ),
        AppCard(
          child: Column(
            children: [
              _detailRow(
                icon: Icons.person_outline,
                label: 'Name',
                value: _nameController.text,
              ),
              const Divider(height: 1),
              _detailRow(
                icon: Icons.phone_outlined,
                label: 'Phone number',
                value: _phoneController.text,
              ),
              const Divider(height: 1),
              _detailRow(
                icon: Icons.directions_car_outlined,
                label: 'Vehicle number',
                value: _vehicleController.text,
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        PrimaryButton(
          label: 'Edit profile',
          icon: Icons.edit_outlined,
          onPressed: _startEditing,
        ),
        const SizedBox(height: AppSpacing.sm),
        PrimaryButton(
          label: 'Logout',
          icon: Icons.logout,
          variant: PrimaryButtonVariant.outlined,
          isLoading: _loggingOut,
          onPressed: _loggingOut ? null : _logout,
        ),
        const SizedBox(height: AppSpacing.lg),
      ],
    );
  }

  Widget _detailRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    final trimmed = value.trim();
    return ListTile(
      leading: Icon(icon, size: 22),
      title: Text(label, style: const TextStyle(fontSize: 13)),
      subtitle: trimmed.isEmpty ? null : Text(trimmed),
      dense: true,
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
            label: 'Name',
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
    );
  }
}
