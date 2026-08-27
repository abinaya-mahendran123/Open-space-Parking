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
import 'package:open_space_parking/features/land_owner/domain/entities/owner_details.dart';
import 'package:open_space_parking/features/land_owner/presentation/providers/land_owner_providers.dart';

class LandOwnerPersonalInfoPage extends ConsumerStatefulWidget {
  const LandOwnerPersonalInfoPage({super.key});

  @override
  ConsumerState<LandOwnerPersonalInfoPage> createState() =>
      _LandOwnerPersonalInfoPageState();
}

class _LandOwnerPersonalInfoPageState
    extends ConsumerState<LandOwnerPersonalInfoPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _emailController;
  late final TextEditingController _addressController;
  bool _initialized = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _phoneController = TextEditingController();
    _emailController = TextEditingController();
    _addressController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  void _fill(OwnerDetails? profile, AuthSession? session) {
    final merged = ProfilePrefill.mergeOwnerDetails(
      saved: profile,
      accountDisplayName: session?.displayName,
      accountEmail: session?.email,
      session: session,
    );
    if (!_initialized) {
      _nameController.text = merged.fullName;
      _phoneController.text = merged.phone;
      _emailController.text = merged.email;
      _addressController.text = merged.address;
      _initialized = true;
      return;
    }
    if (_nameController.text.isEmpty) _nameController.text = merged.fullName;
    if (_phoneController.text.isEmpty) _phoneController.text = merged.phone;
    if (_emailController.text.isEmpty) _emailController.text = merged.email;
    if (_addressController.text.isEmpty) {
      _addressController.text = merged.address;
    }
  }

  Future<void> _save(String ownerId) async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);
    try {
      await ref.read(landOwnerRepositoryProvider).updateOwnerProfile(
            ownerId: ownerId,
            ownerDetails: OwnerDetails(
              fullName: _nameController.text.trim(),
              phone: _phoneController.text.trim(),
              email: _emailController.text.trim(),
              address: _addressController.text.trim(),
            ),
          );
      ref.invalidate(landOwnerProfileProvider(ownerId));
      ref.read(snackbarServiceProvider).showSuccess('Personal info saved.');
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
    final ownerId = auth.session?.userId ?? '';
    final profileAsync = ref.watch(landOwnerProfileProvider(ownerId));

    return Scaffold(
      appBar: AppBar(title: const Text('Personal Info')),
      body: profileAsync.when(
        loading: () {
          _fill(null, auth.session);
          return const Center(child: CircularProgressIndicator());
        },
        error: (_, __) {
          _fill(null, auth.session);
          return _form(context, ownerId, showLoadError: true);
        },
        data: (profile) {
          _fill(profile, auth.session);
          return _form(context, ownerId);
        },
      ),
    );
  }

  Widget _form(
    BuildContext context,
    String ownerId, {
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
                    ref.invalidate(landOwnerProfileProvider(ownerId)),
                child: const Text('Retry'),
              ),
              const SizedBox(height: 12),
            ],
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
              label: 'Address',
              validator: (v) =>
                  Validators.requiredField(v, fieldName: 'Address'),
            ),
            const SizedBox(height: 24),
            PrimaryButton(
              label: 'Save',
              isLoading: _saving,
              onPressed: () => _save(ownerId),
            ),
          ],
        ),
      ),
    );
  }
}
