import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:open_space_parking/core/common/exceptions/app_exception.dart';
import 'package:open_space_parking/core/providers/core_providers.dart';
import 'package:open_space_parking/core/utils/profile_prefill.dart';
import 'package:open_space_parking/core/utils/validators.dart';
import 'package:open_space_parking/core/widgets/buttons/primary_button.dart';
import 'package:open_space_parking/core/widgets/textfields/app_text_field.dart';
import 'package:open_space_parking/features/authentication/presentation/providers/auth_state_provider.dart';
import 'package:open_space_parking/features/land_owner/domain/entities/owner_details.dart';
import 'package:open_space_parking/features/land_owner/domain/entities/payout_account.dart';
import 'package:open_space_parking/features/land_owner/presentation/providers/land_owner_providers.dart';

class LandOwnerAccountDetailsPage extends ConsumerStatefulWidget {
  const LandOwnerAccountDetailsPage({super.key});

  @override
  ConsumerState<LandOwnerAccountDetailsPage> createState() =>
      _LandOwnerAccountDetailsPageState();
}

class _LandOwnerAccountDetailsPageState
    extends ConsumerState<LandOwnerAccountDetailsPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _accountNameController;
  late final TextEditingController _upiController;
  late final TextEditingController _bankAccountController;
  late final TextEditingController _ifscController;
  late final TextEditingController _razorpayAccountController;
  bool _payoutInitialized = false;
  bool _saving = false;
  bool _payoutListenerRegistered = false;

  @override
  void initState() {
    super.initState();
    _accountNameController = TextEditingController();
    _upiController = TextEditingController();
    _bankAccountController = TextEditingController();
    _ifscController = TextEditingController();
    _razorpayAccountController = TextEditingController();
  }

  @override
  void dispose() {
    _accountNameController.dispose();
    _upiController.dispose();
    _bankAccountController.dispose();
    _ifscController.dispose();
    _razorpayAccountController.dispose();
    super.dispose();
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

  Future<void> _save(String ownerId, OwnerDetails? existing) async {
    if (!_formKey.currentState!.validate()) return;

    final auth = ref.read(authStateProvider).session;
    final merged = ProfilePrefill.mergeOwnerDetails(
      saved: existing,
      accountDisplayName: auth?.displayName,
      accountEmail: auth?.email,
      session: auth,
    );

    setState(() => _saving = true);
    try {
      await ref.read(landOwnerRepositoryProvider).updateOwnerProfile(
            ownerId: ownerId,
            ownerDetails: OwnerDetails(
              fullName: merged.fullName,
              phone: merged.phone,
              email: merged.email,
              address: merged.address,
            ),
            payoutAccount: PayoutAccount(
              accountHolderName: _accountNameController.text.trim(),
              upiId: _upiController.text.trim(),
              bankAccountNumber: _bankAccountController.text.trim(),
              ifscCode: _ifscController.text.trim().toUpperCase(),
              razorpayLinkedAccountId: _razorpayAccountController.text.trim(),
            ),
          );
      ref.invalidate(landOwnerPayoutProvider(ownerId));
      ref.read(snackbarServiceProvider).showSuccess('Account details saved.');
    } on AppException catch (e) {
      ref.read(snackbarServiceProvider).showError(e.message);
    } catch (_) {
      ref
          .read(snackbarServiceProvider)
          .showError('Could not update account details.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authStateProvider);
    final ownerId = auth.session?.userId ?? '';
    final profileAsync = ref.watch(landOwnerProfileProvider(ownerId));
    final payoutAsync = ref.watch(landOwnerPayoutProvider(ownerId));

    if (!_payoutListenerRegistered && ownerId.isNotEmpty) {
      _payoutListenerRegistered = true;
      ref.listenManual(
        landOwnerPayoutProvider(ownerId),
        (_, next) => next.whenData(_fillPayout),
        fireImmediately: true,
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Account Details')),
      body: payoutAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => _form(
          ownerId,
          existing: profileAsync.asData?.value,
          showLoadError: true,
        ),
        data: (_) => _form(
          ownerId,
          existing: profileAsync.asData?.value,
        ),
      ),
    );
  }

  Widget _form(
    String ownerId, {
    OwnerDetails? existing,
    bool showLoadError = false,
  }) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (showLoadError) ...[
              Text(
                'Could not refresh payout details. You can still edit and save.',
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
              TextButton(
                onPressed: () =>
                    ref.invalidate(landOwnerPayoutProvider(ownerId)),
                child: const Text('Retry'),
              ),
              const SizedBox(height: 12),
            ],
            Text(
              'Payout account (90% of parking fees)',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            Text(
              '90% goes to this account. 10% goes to Open Space Parking.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
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
              label: 'Razorpay linked account',
              hint: 'acc_xxxxxxxxxx',
              validator: Validators.razorpayLinkedAccount,
            ),
            const SizedBox(height: 24),
            PrimaryButton(
              label: 'Save',
              isLoading: _saving,
              onPressed: () => _save(ownerId, existing),
            ),
          ],
        ),
      ),
    );
  }
}
