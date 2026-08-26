import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:open_space_parking/core/common/exceptions/app_exception.dart';
import 'package:open_space_parking/core/providers/core_providers.dart';
import 'package:open_space_parking/core/routes/route_paths.dart';
import 'package:open_space_parking/core/utils/validators.dart';
import 'package:open_space_parking/core/widgets/buttons/primary_button.dart';
import 'package:open_space_parking/core/widgets/textfields/app_text_field.dart';
import 'package:open_space_parking/core/utils/profile_prefill.dart';
import 'package:open_space_parking/features/authentication/domain/entities/auth_session.dart';
import 'package:open_space_parking/features/authentication/presentation/providers/auth_state_provider.dart';
import 'package:open_space_parking/features/land_owner/domain/entities/owner_details.dart';
import 'package:open_space_parking/features/land_owner/domain/entities/payout_account.dart';
import 'package:open_space_parking/features/land_owner/presentation/providers/land_owner_providers.dart';

class LandOwnerProfilePage extends ConsumerStatefulWidget {
  const LandOwnerProfilePage({super.key});

  @override
  ConsumerState<LandOwnerProfilePage> createState() => _LandOwnerProfilePageState();
}

class _LandOwnerProfilePageState extends ConsumerState<LandOwnerProfilePage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _emailController;
  late final TextEditingController _addressController;
  late final TextEditingController _accountNameController;
  late final TextEditingController _upiController;
  late final TextEditingController _bankAccountController;
  late final TextEditingController _ifscController;
  late final TextEditingController _razorpayAccountController;
  bool _initialized = false;
  bool _payoutInitialized = false;
  bool _saving = false;
  bool _payoutListenerRegistered = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _phoneController = TextEditingController();
    _emailController = TextEditingController();
    _addressController = TextEditingController();
    _accountNameController = TextEditingController();
    _upiController = TextEditingController();
    _bankAccountController = TextEditingController();
    _ifscController = TextEditingController();
    _razorpayAccountController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    _accountNameController.dispose();
    _upiController.dispose();
    _bankAccountController.dispose();
    _ifscController.dispose();
    _razorpayAccountController.dispose();
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

  void _fillPayout(PayoutAccount? payout) {
    if (_payoutInitialized || payout == null) return;
    _accountNameController.text = payout.accountHolderName ?? '';
    _upiController.text = payout.upiId ?? '';
    _bankAccountController.text = payout.bankAccountNumber ?? '';
    _ifscController.text = payout.ifscCode ?? '';
    _razorpayAccountController.text = payout.razorpayLinkedAccountId ?? '';
    _payoutInitialized = true;
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
            payoutAccount: PayoutAccount(
              accountHolderName: _accountNameController.text.trim(),
              upiId: _upiController.text.trim(),
              bankAccountNumber: _bankAccountController.text.trim(),
              ifscCode: _ifscController.text.trim().toUpperCase(),
              razorpayLinkedAccountId: _razorpayAccountController.text.trim(),
            ),
          );
      ref.invalidate(landOwnerProfileProvider(ownerId));
      ref.invalidate(landOwnerPayoutProvider(ownerId));
      ref.read(snackbarServiceProvider).showSuccess(
            'Profile and payout account saved.',
          );
    } on AppException catch (e) {
      ref.read(snackbarServiceProvider).showError(e.message);
    } catch (_) {
      ref.read(snackbarServiceProvider).showError('Could not update profile.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _logout() async {
    final result = await showDialog<bool>(
      context: context,
      useRootNavigator: true,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
    if (result != true || !mounted) return;

    await ref.read(authStateProvider.notifier).logout();
    if (!mounted) return;
    GoRouter.of(context).go(RoutePaths.authEntry);
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authStateProvider);
    final ownerId = auth.session?.userId ?? '';
    final profileAsync = ref.watch(landOwnerProfileProvider(ownerId));

    // Register payout listener once — avoids side-effects in build().
    if (!_payoutListenerRegistered && ownerId.isNotEmpty) {
      _payoutListenerRegistered = true;
      ref.listenManual(
        landOwnerPayoutProvider(ownerId),
        (_, next) => next.whenData(_fillPayout),
        fireImmediately: true,
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: profileAsync.when(
        loading: () {
          _fill(null, auth.session);
          return const Center(child: CircularProgressIndicator());
        },
        error: (_, __) {
          _fill(null, auth.session);
          return _profileForm(context, ownerId, showLoadError: true);
        },
        data: (profile) {
          _fill(profile, auth.session);
          return _profileForm(context, ownerId);
        },
      ),
    );
  }

  Widget _profileForm(
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
            CircleAvatar(
              radius: 40,
              child: Text(
                (_nameController.text.isNotEmpty
                        ? _nameController.text[0]
                        : 'L')
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
              label: 'Address',
              validator: (v) => Validators.requiredField(v, fieldName: 'Address'),
            ),
            const SizedBox(height: 24),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Payout account (90% of parking fees)',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'When a driver pays, 10% goes to the Open Space Parking media '
              'Razorpay account and 90% is settled to this land-owner account. '
              'Save UPI or bank details (or a Razorpay linked account id).',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            AppTextField(
              controller: _accountNameController,
              label: 'Account holder name',
            ),
            const SizedBox(height: 12),
            AppTextField(
              controller: _upiController,
              label: 'UPI ID',
              hint: 'name@oksbi',
              validator: Validators.optionalUpi,
            ),
            const SizedBox(height: 12),
            AppTextField(
              controller: _bankAccountController,
              label: 'Bank account number',
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 12),
            AppTextField(
              controller: _ifscController,
              label: 'IFSC code',
              hint: 'SBIN0001234',
              validator: Validators.optionalIfsc,
            ),
            const SizedBox(height: 12),
            AppTextField(
              controller: _razorpayAccountController,
              label: 'Razorpay linked account (optional)',
              hint: 'acc_xxxxxxxxxx',
            ),
            const SizedBox(height: 24),
            PrimaryButton(
              label: 'Save Profile',
              isLoading: _saving,
              onPressed: () => _save(ownerId),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _logout,
              icon: const Icon(Icons.logout),
              label: const Text('Logout'),
            ),
          ],
        ),
      ),
    );
  }
}
