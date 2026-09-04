import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:open_space_parking/core/common/exceptions/app_exception.dart';
import 'package:open_space_parking/core/providers/core_providers.dart';
import 'package:open_space_parking/core/routes/route_paths.dart';
import 'package:open_space_parking/core/utils/parking_slot_calculator.dart';
import 'package:open_space_parking/core/widgets/buttons/primary_button.dart';
import 'package:open_space_parking/core/utils/profile_prefill.dart';
import 'package:open_space_parking/features/authentication/presentation/providers/auth_state_provider.dart';
import 'package:open_space_parking/features/land_owner/presentation/providers/aadhaar_ocr_provider.dart';
import 'package:open_space_parking/features/land_owner/presentation/providers/land_owner_providers.dart';
import 'package:open_space_parking/features/notification/domain/entities/notification_recipient_type.dart';
import 'package:open_space_parking/features/notification/presentation/providers/notification_providers.dart';
import 'package:open_space_parking/features/land_owner/presentation/widgets/land_details_form.dart';
import 'package:open_space_parking/features/land_owner/domain/entities/owner_details.dart';
import 'package:open_space_parking/features/land_owner/presentation/widgets/government_id_owner_details_form.dart';
import 'package:open_space_parking/features/land_owner/presentation/widgets/land_owner_step_scaffold.dart';
import 'package:open_space_parking/features/land_owner/presentation/widgets/upload_documents_form.dart';

class ExistingParkingFlowPage extends ConsumerStatefulWidget {
  const ExistingParkingFlowPage({super.key});

  @override
  ConsumerState<ExistingParkingFlowPage> createState() =>
      _ExistingParkingFlowPageState();
}

class _ExistingParkingFlowPageState extends ConsumerState<ExistingParkingFlowPage> {
  final _ownerFormKey = GlobalKey<GovernmentIdOwnerDetailsFormState>();
  final _landFormKey = GlobalKey<LandDetailsFormState>();
  final _docsFormKey = GlobalKey<UploadDocumentsFormState>();

  static const _stepLabels = [
    'Aadhaar Upload',
    'Land & Area',
    'Document Verification',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _seedOwnerDetails());
  }

  Future<void> _seedOwnerDetails() async {
    final ownerId = ref.read(authStateProvider).session?.userId;
    if (ownerId == null) return;

    final form = ref.read(existingParkingFormProvider);
    if (form.ownerDetails != null) return;

    try {
      final profile = await ref
          .read(landOwnerProfileProvider(ownerId).future)
          .timeout(const Duration(seconds: 10));
      if (!mounted) return;
      final session = ref.read(authStateProvider).session;
      final merged = ProfilePrefill.mergeOwnerDetails(
        saved: profile,
        accountDisplayName: session?.displayName,
        accountEmail: session?.email,
        session: session,
      );
      if (!ProfilePrefill.hasAnyOwnerDetails(merged)) return;
      ref.read(existingParkingFormProvider.notifier).setOwnerDetails(merged);
    } catch (_) {
      // Profile seed is best-effort — user can fill manually.
    }
  }

  void _saveOwnerDetails(OwnerDetails details) {
    final notifier = ref.read(existingParkingFormProvider.notifier);
    notifier.setOwnerDetails(details);
    if (details.governmentIdFrontPath != null) {
      final current = ref.read(existingParkingFormProvider).documents;
      notifier.setDocuments(
        current.copyWith(governmentIdPath: details.governmentIdFrontPath),
      );
    }
  }

  Future<void> _submit() async {
    final form = ref.read(existingParkingFormProvider);
    final ownerId = ref.read(authStateProvider).session?.userId;
    if (ownerId == null ||
        form.ownerDetails == null ||
        form.landDetails == null ||
        !form.documents.isComplete) {
      ref.read(snackbarServiceProvider).showError('Please complete all steps.');
      return;
    }

    final loading = ref.read(landOwnerLoadingProvider.notifier);
    loading.state = true;

    try {
      await ref.read(landOwnerRepositoryProvider).submitExistingParkingRequest(
            ownerId: ownerId,
            ownerDetails: form.ownerDetails!,
            documents: form.documents,
            landDetails: form.landDetails!,
          );

      ref.invalidate(requestHistoryProvider(ownerId));
      invalidateNotificationCache(
        ref,
        recipientId: ownerId,
        recipientType: NotificationRecipientType.landOwner,
      );
      ref.invalidate(unreadNotificationCountProvider(ownerId));

      if (!mounted) return;
      ref.read(snackbarServiceProvider).showSuccess('Request submitted successfully.');
      ref.read(existingParkingFormProvider.notifier).reset();
      context.go(RoutePaths.landOwnerHistory);
    } on AppException catch (e) {
      ref.read(snackbarServiceProvider).showError(e.message);
    } catch (_) {
      ref.read(snackbarServiceProvider).showError('Submission failed.');
    } finally {
      loading.state = false;
    }
  }

  Future<void> _nextStep() async {
    final notifier = ref.read(existingParkingFormProvider.notifier);
    final step = ref.read(existingParkingFormProvider).currentStep;

    if (step == 0 && !(_ownerFormKey.currentState?.validateAndSave() ?? false)) {
      return;
    }
    if (step == 1 &&
        !await (_landFormKey.currentState?.validateAndSave() ?? Future.value(false))) {
      return;
    }
    if (step == 2 && !(_docsFormKey.currentState?.isComplete ?? false)) {
      ref.read(snackbarServiceProvider).showError('Please upload all documents.');
      return;
    }

    notifier.nextStep();
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(authStateProvider).session;
    ref.listen<AadhaarOcrState>(aadhaarOcrProvider, (previous, next) {
      if (next.isRunning || next.result == null || next.uploadUrl == null) return;
      final details = ownerDetailsFromOcr(
        result: next.result!,
        uploadedUrl: next.uploadUrl!,
        accountEmail: session?.email,
        existing: ref.read(existingParkingFormProvider).ownerDetails,
      );
      ref.read(existingParkingFormProvider.notifier).setOwnerDetails(details);
    });

    final form = ref.watch(existingParkingFormProvider);
    final isLoading = ref.watch(landOwnerLoadingProvider);
    final step = form.currentStep;
    final isLastStep = step == ExistingParkingFormState.totalSteps - 1;

    return LandOwnerStepScaffold(
      title: 'Already Have Parking',
      currentStep: step,
      totalSteps: ExistingParkingFormState.totalSteps,
      stepLabels: _stepLabels,
      onBack: () {
        if (step == 0) {
          ref.read(existingParkingFormProvider.notifier).reset();
          context.pop();
        } else {
          ref.read(existingParkingFormProvider.notifier).previousStep();
        }
      },
      bottomBar: isLastStep
          ? PrimaryButton(label: 'Submit', isLoading: isLoading, onPressed: _submit)
          : PrimaryButton(label: 'Continue', onPressed: _nextStep),
      child: switch (step) {
        0 => GovernmentIdOwnerDetailsForm(
            key: _ownerFormKey,
            initial: form.ownerDetails,
            ownerId: ref.watch(authStateProvider).session?.userId ?? '',
            accountEmail: ref.watch(authStateProvider).session?.email,
            onSave: _saveOwnerDetails,
          ),
        1 => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              LandDetailsForm(
                key: _landFormKey,
                initial: form.landDetails,
                onSave:
                    ref.read(existingParkingFormProvider.notifier).setLandDetails,
              ),
              const SizedBox(height: 16),
              Text(
                'Slots are calculated from land area: '
                '${ParkingSlotCalculator.sqFtPerCar.toStringAsFixed(0)} sq ft per car '
                '(basic stall + aisle).',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              if (form.landDetails != null && form.landDetails!.areaSqFt > 0) ...[
                const SizedBox(height: 8),
                Text(
                  'Estimated slots: '
                  '${ParkingSlotCalculator.slotsFromLandArea(form.landDetails!.areaSqFt)}',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ],
            ],
          ),
        2 => UploadDocumentsForm(
            key: _docsFormKey,
            initial: form.documents,
            ownerId: ref.watch(authStateProvider).session?.userId ?? '',
            onChanged: ref.read(existingParkingFormProvider.notifier).setDocuments,
          ),
        _ => const SizedBox.shrink(),
      },
    );
  }
}
