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
  late final TextEditingController _panController;
  late final TextEditingController _upiController;
  late final TextEditingController _bankAccountController;
  late final TextEditingController _ifscController;
  late final TextEditingController _cityController;
  late final TextEditingController _stateController;
  late final TextEditingController _postalController;
  bool _payoutInitialized = false;
  bool _saving = false;
  bool _refreshingStatus = false;
  bool _payoutListenerRegistered = false;
  PayoutAccount? _savedPayout;

  @override
  void initState() {
    super.initState();
    _accountNameController = TextEditingController();
    _panController = TextEditingController();
    _upiController = TextEditingController();
    _bankAccountController = TextEditingController();
    _ifscController = TextEditingController();
    _cityController = TextEditingController();
    _stateController = TextEditingController();
    _postalController = TextEditingController();
  }

  @override
  void dispose() {
    _accountNameController.dispose();
    _panController.dispose();
    _upiController.dispose();
    _bankAccountController.dispose();
    _ifscController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _postalController.dispose();
    super.dispose();
  }

  void _fillPayout(PayoutAccount? payout) {
    if (_payoutInitialized || payout == null) return;
    _accountNameController.text = payout.accountHolderName ?? '';
    _panController.text = payout.pan ?? '';
    _upiController.text = payout.upiId ?? '';
    _bankAccountController.text = payout.bankAccountNumber ?? '';
    _ifscController.text = payout.ifscCode ?? '';
    _cityController.text = payout.city ?? '';
    _stateController.text = payout.state ?? '';
    _postalController.text = payout.postalCode ?? '';
    _savedPayout = payout;
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
      final payout = await ref
          .read(landOwnerRepositoryProvider)
          .onboardRazorpayPayout(
            ownerId: ownerId,
            ownerDetails: OwnerDetails(
              fullName: merged.fullName,
              phone: merged.phone,
              email: merged.email,
              address: merged.address,
            ),
            payoutAccount: PayoutAccount(
              accountHolderName: _accountNameController.text.trim(),
              pan: _panController.text.trim().toUpperCase(),
              upiId: _upiController.text.trim(),
              bankAccountNumber: _bankAccountController.text.trim(),
              ifscCode: _ifscController.text.trim().toUpperCase(),
              city: _cityController.text.trim(),
              state: _stateController.text.trim().toUpperCase(),
              postalCode: _postalController.text.trim(),
              razorpayLinkedAccountId: _savedPayout?.razorpayLinkedAccountId,
              razorpayProductId: _savedPayout?.razorpayProductId,
              razorpayActivationStatus: _savedPayout?.razorpayActivationStatus,
            ),
          );
      _savedPayout = payout;
      ref.invalidate(landOwnerPayoutProvider(ownerId));
      ref.invalidate(landOwnerProfileProvider(ownerId));
      final message = payout.razorpayStatusMessage?.trim().isNotEmpty == true
          ? payout.razorpayStatusMessage!
          : 'Account details saved.';
      if (payout.razorpayActivationStatus == 'failed') {
        ref.read(snackbarServiceProvider).showError(message);
      } else {
        ref.read(snackbarServiceProvider).showSuccess(message);
      }
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

  Future<void> _refreshStatus(String ownerId) async {
    setState(() => _refreshingStatus = true);
    try {
      final payout = await ref
          .read(landOwnerRepositoryProvider)
          .refreshRazorpayPayoutStatus(ownerId);
      if (payout != null) {
        _savedPayout = payout;
        ref.invalidate(landOwnerPayoutProvider(ownerId));
        ref.read(snackbarServiceProvider).showSuccess(
              payout.razorpayStatusMessage ?? payout.statusLabel,
            );
      }
    } on AppException catch (e) {
      ref.read(snackbarServiceProvider).showError(e.message);
    } catch (_) {
      ref
          .read(snackbarServiceProvider)
          .showError('Could not refresh payout status.');
    } finally {
      if (mounted) setState(() => _refreshingStatus = false);
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
        data: (payout) {
          _savedPayout ??= payout;
          return _form(
            ownerId,
            existing: profileAsync.asData?.value,
          );
        },
      ),
    );
  }

  Widget _form(
    String ownerId, {
    OwnerDetails? existing,
    bool showLoadError = false,
  }) {
    final theme = Theme.of(context);
    final status = _savedPayout;

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
                style: theme.textTheme.bodySmall,
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
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            Text(
              '90% goes to this bank account. 10% stays with E Star (merchant). '
              'Saving creates a Razorpay linked account automatically — you do not enter an acc_ ID.',
              style: theme.textTheme.bodySmall,
            ),
            if (status != null) ...[
              const SizedBox(height: 16),
              _StatusCard(
                payout: status,
                refreshing: _refreshingStatus,
                onRefresh: status.hasRazorpayLinkedAccount
                    ? () => _refreshStatus(ownerId)
                    : null,
              ),
            ],
            const SizedBox(height: 16),
            AppTextField(
              controller: _accountNameController,
              label: 'Account holder name',
              validator: Validators.requiredAccountHolder,
            ),
            const SizedBox(height: 12),
            AppTextField(
              controller: _panController,
              label: 'PAN',
              hint: 'ABCDE1234F',
              textCapitalization: TextCapitalization.characters,
              validator: Validators.requiredPan,
            ),
            const SizedBox(height: 12),
            AppTextField(
              controller: _bankAccountController,
              label: 'Bank account number',
              keyboardType: TextInputType.number,
              validator: Validators.requiredBankAccount,
            ),
            const SizedBox(height: 12),
            AppTextField(
              controller: _ifscController,
              label: 'IFSC code',
              hint: 'SBIN0001234',
              textCapitalization: TextCapitalization.characters,
              validator: Validators.requiredIfsc,
            ),
            const SizedBox(height: 12),
            AppTextField(
              controller: _cityController,
              label: 'City',
            ),
            const SizedBox(height: 12),
            AppTextField(
              controller: _stateController,
              label: 'State',
              hint: 'TN / KA / MH',
              textCapitalization: TextCapitalization.characters,
            ),
            const SizedBox(height: 12),
            AppTextField(
              controller: _postalController,
              label: 'PIN code',
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 12),
            AppTextField(
              controller: _upiController,
              label: 'UPI ID (optional)',
              hint: 'name@oksbi',
              validator: Validators.optionalUpi,
            ),
            const SizedBox(height: 24),
            PrimaryButton(
              label: 'Save & set up payout',
              isLoading: _saving,
              onPressed: () => _save(ownerId, existing),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({
    required this.payout,
    required this.refreshing,
    this.onRefresh,
  });

  final PayoutAccount payout;
  final bool refreshing;
  final VoidCallback? onRefresh;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final status = (payout.razorpayActivationStatus ?? '').toLowerCase();
    final color = switch (status) {
      'activated' => Colors.green.shade700,
      'failed' => theme.colorScheme.error,
      'not_configured' => theme.colorScheme.outline,
      _ => theme.colorScheme.primary,
    };

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: color.withValues(alpha: 0.35)),
        borderRadius: BorderRadius.circular(12),
        color: color.withValues(alpha: 0.06),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            payout.statusLabel,
            style: theme.textTheme.titleSmall?.copyWith(color: color),
          ),
          if (payout.hasRazorpayLinkedAccount) ...[
            const SizedBox(height: 4),
            Text(
              'Linked account: ${payout.razorpayLinkedAccountId}',
              style: theme.textTheme.bodySmall,
            ),
          ],
          if ((payout.razorpayStatusMessage ?? '').isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              payout.razorpayStatusMessage!,
              style: theme.textTheme.bodySmall,
            ),
          ],
          if (onRefresh != null) ...[
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: refreshing ? null : onRefresh,
              icon: refreshing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh, size: 18),
              label: const Text('Refresh status'),
            ),
          ],
        ],
      ),
    );
  }
}
