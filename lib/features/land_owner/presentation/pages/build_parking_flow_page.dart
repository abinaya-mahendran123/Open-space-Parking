import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:open_space_parking/core/common/exceptions/app_exception.dart';
import 'package:open_space_parking/core/providers/core_providers.dart';
import 'package:open_space_parking/core/routes/route_paths.dart';
import 'package:open_space_parking/core/widgets/buttons/primary_button.dart';
import 'package:open_space_parking/features/authentication/presentation/providers/auth_state_provider.dart';
import 'package:open_space_parking/core/utils/profile_prefill.dart';
import 'package:open_space_parking/features/land_owner/domain/entities/owner_details.dart';
import 'package:open_space_parking/features/land_owner/domain/entities/parking_preferences.dart';
import 'package:open_space_parking/features/land_owner/domain/entities/parking_type.dart';
import 'package:open_space_parking/features/land_owner/domain/entities/request_priority.dart';
import 'package:open_space_parking/features/land_owner/presentation/providers/aadhaar_ocr_provider.dart';
import 'package:open_space_parking/features/land_owner/presentation/providers/land_owner_providers.dart';
import 'package:open_space_parking/features/notification/domain/entities/notification_recipient_type.dart';
import 'package:open_space_parking/features/notification/presentation/providers/notification_providers.dart';
import 'package:open_space_parking/features/land_owner/presentation/widgets/land_details_form.dart';
import 'package:open_space_parking/features/land_owner/presentation/widgets/government_id_owner_details_form.dart';
import 'package:open_space_parking/features/land_owner/presentation/widgets/land_owner_step_scaffold.dart';
import 'package:open_space_parking/features/land_owner/presentation/widgets/parking_type_carousel.dart';
import 'package:open_space_parking/features/land_owner/presentation/widgets/review_ticket_form.dart';
import 'package:open_space_parking/features/land_owner/presentation/widgets/upload_documents_form.dart';

class BuildParkingFlowPage extends ConsumerStatefulWidget {
  const BuildParkingFlowPage({super.key});

  @override
  ConsumerState<BuildParkingFlowPage> createState() => _BuildParkingFlowPageState();
}

class _BuildParkingFlowPageState extends ConsumerState<BuildParkingFlowPage> {
  final _ownerFormKey = GlobalKey<GovernmentIdOwnerDetailsFormState>();
  final _landFormKey = GlobalKey<LandDetailsFormState>();
  final _docsFormKey = GlobalKey<UploadDocumentsFormState>();
  final _carsController = TextEditingController();
  final _reviewFormKey = GlobalKey<ReviewTicketFormState>();

  static const _stepLabels = [
    'Aadhaar Upload',
    'Land & Area',
    'Document Verification',
    'Parking Preferences',
    'Review Ticket',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _seedOwnerDetails();
      final cars = ref.read(buildParkingFormProvider).numberOfCars;
      if (cars > 1) {
        _carsController.text = '$cars';
      }
    });
  }

  Future<void> _seedOwnerDetails() async {
    final ownerId = ref.read(authStateProvider).session?.userId;
    if (ownerId == null) return;

    final form = ref.read(buildParkingFormProvider);
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
      ref.read(buildParkingFormProvider.notifier).setOwnerDetails(merged);
    } catch (_) {
      // Profile seed is best-effort — user can fill manually.
    }
  }

  @override
  void dispose() {
    _carsController.dispose();
    super.dispose();
  }

  void _saveOwnerDetails(OwnerDetails details) {
    final notifier = ref.read(buildParkingFormProvider.notifier);
    notifier.setOwnerDetails(details);
    if (details.governmentIdFrontPath != null) {
      final current = ref.read(buildParkingFormProvider).documents;
      notifier.setDocuments(
        current.copyWith(governmentIdPath: details.governmentIdFrontPath),
      );
    }
  }

  int? _parsedCarCount() {
    final raw = _carsController.text.trim();
    if (raw.isEmpty) return null;
    return int.tryParse(raw);
  }

  Future<void> _submit() async {
    final reviewOk = _reviewFormKey.currentState?.validateAndSave() ?? false;
    if (!reviewOk) {
      ref.read(snackbarServiceProvider).showError(
            'Fix the highlighted review fields before submitting.',
          );
      return;
    }

    final form = ref.read(buildParkingFormProvider);
    final ownerId = ref.read(authStateProvider).session?.userId;
    if (ownerId == null ||
        form.ownerDetails == null ||
        form.landDetails == null ||
        !form.documents.isComplete) {
      ref.read(snackbarServiceProvider).showError('Please complete all steps.');
      return;
    }

    final cars = form.numberOfCars > 0 ? form.numberOfCars : _parsedCarCount();
    if (cars == null || cars <= 0) {
      ref.read(snackbarServiceProvider).showError('Enter a valid number of cars.');
      return;
    }

    final loading = ref.read(landOwnerLoadingProvider.notifier);
    loading.state = true;

    try {
      final request = await ref.read(landOwnerRepositoryProvider).submitBuildParkingRequest(
            ownerId: ownerId,
            ownerDetails: form.ownerDetails!,
            documents: form.documents,
            landDetails: form.landDetails!,
            parkingPreferences: ParkingPreferences(
              priority: form.priority,
              parkingType: form.parkingType,
              numberOfCars: cars,
            ),
          );

      ref.read(buildParkingFormProvider.notifier).setGeneratedTicketId(request.ticketId);
      ref.invalidate(requestHistoryProvider(ownerId));
      invalidateNotificationCache(
        ref,
        recipientId: ownerId,
        recipientType: NotificationRecipientType.landOwner,
      );
      ref.invalidate(unreadNotificationCountProvider(ownerId));

      if (!mounted) return;
      ref.read(snackbarServiceProvider).showSuccess('Request submitted to admin.');
      ref.read(buildParkingFormProvider.notifier).reset();
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
    final notifier = ref.read(buildParkingFormProvider.notifier);
    final step = ref.read(buildParkingFormProvider).currentStep;

    if (step == 0 && !(_ownerFormKey.currentState?.validateAndSave() ?? false)) {
      return;
    }
    if (step == 1 &&
        !await (_landFormKey.currentState?.validateAndSave() ?? Future.value(false))) {
      return;
    }
    if (step == 2 && !(_docsFormKey.currentState?.isComplete ?? false)) {
      ref.read(snackbarServiceProvider).showError(
            _docsFormKey.currentState?.blockingMessage ??
                'Please upload and verify all required documents.',
          );
      return;
    }
    if (step == 3) {
      final cars = _parsedCarCount();
      if (cars == null || cars <= 0) {
        ref.read(snackbarServiceProvider).showError(
              'Enter the number of cars / slots.',
            );
        return;
      }
      notifier.setNumberOfCars(cars);
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
        existing: ref.read(buildParkingFormProvider).ownerDetails,
      );
      ref.read(buildParkingFormProvider.notifier).setOwnerDetails(details);
    });

    final form = ref.watch(buildParkingFormProvider);
    final isLoading = ref.watch(landOwnerLoadingProvider);
    final step = form.currentStep;

    return LandOwnerStepScaffold(
      title: 'Build Parking',
      currentStep: step,
      totalSteps: BuildParkingFormState.totalSteps,
      stepLabels: _stepLabels,
      onBack: () {
        if (step == 0) {
          ref.read(buildParkingFormProvider.notifier).reset();
          context.pop();
        } else {
          ref.read(buildParkingFormProvider.notifier).previousStep();
        }
      },
      bottomBar: step < 4
          ? PrimaryButton(label: 'Continue', onPressed: _nextStep)
          : PrimaryButton(
              label: 'Submit to Admin',
              isLoading: isLoading,
              onPressed: _submit,
            ),
      child: _buildStepContent(form),
    );
  }

  Widget _buildStepContent(BuildParkingFormState form) {
    switch (form.currentStep) {
      case 0:
        return GovernmentIdOwnerDetailsForm(
          key: _ownerFormKey,
          initial: form.ownerDetails,
          ownerId: ref.watch(authStateProvider).session?.userId ?? '',
          accountEmail: ref.watch(authStateProvider).session?.email,
          onSave: _saveOwnerDetails,
        );
      case 1:
        return LandDetailsForm(
          key: _landFormKey,
          initial: form.landDetails,
          onSave: ref.read(buildParkingFormProvider.notifier).setLandDetails,
        );
      case 2:
        return UploadDocumentsForm(
          key: _docsFormKey,
          initial: form.documents,
          ownerId: ref.watch(authStateProvider).session?.userId ?? '',
          onChanged: ref.read(buildParkingFormProvider.notifier).setDocuments,
        );
      case 3:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Priority', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            SegmentedButton<RequestPriority>(
              segments: RequestPriority.values
                  .map((p) => ButtonSegment(value: p, label: Text(p.label)))
                  .toList(),
              selected: {form.priority},
              onSelectionChanged: (s) =>
                  ref.read(buildParkingFormProvider.notifier).setPriority(s.first),
            ),
            const SizedBox(height: 20),
            Text('Parking Type', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            ParkingTypeCarousel(
              selectedType: form.parkingType,
              onTypeSelected:
                  ref.read(buildParkingFormProvider.notifier).setParkingType,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<ParkingType>(
              initialValue: form.parkingType,
              decoration: const InputDecoration(labelText: 'Parking Type'),
              items: ParkingType.values
                  .map((t) => DropdownMenuItem(value: t, child: Text(t.label)))
                  .toList(),
              onChanged: (v) {
                if (v != null) {
                  ref.read(buildParkingFormProvider.notifier).setParkingType(v);
                }
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _carsController,
              decoration: const InputDecoration(
                labelText: 'No of Cars / Slots',
                hintText: 'e.g. 100 cars',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              onChanged: (v) {
                final cars = int.tryParse(v.trim());
                if (cars != null && cars > 0) {
                  ref.read(buildParkingFormProvider.notifier).setNumberOfCars(cars);
                }
              },
            ),
          ],
        );
      case 4:
        if (form.ownerDetails == null || form.landDetails == null) {
          return const Text('Complete earlier steps to review your ticket.');
        }
        return ReviewTicketForm(
          key: _reviewFormKey,
          mode: ReviewTicketMode.buildParking,
          ownerDetails: form.ownerDetails!,
          landDetails: form.landDetails!,
          priority: form.priority,
          parkingType: form.parkingType,
          numberOfCars: form.numberOfCars,
          onOwnerChanged: ref.read(buildParkingFormProvider.notifier).setOwnerDetails,
          onLandChanged: ref.read(buildParkingFormProvider.notifier).setLandDetails,
          onPriorityChanged: ref.read(buildParkingFormProvider.notifier).setPriority,
          onParkingTypeChanged:
              ref.read(buildParkingFormProvider.notifier).setParkingType,
          onNumberOfCarsChanged:
              ref.read(buildParkingFormProvider.notifier).setNumberOfCars,
        );
      default:
        return const SizedBox.shrink();
    }
  }
}
