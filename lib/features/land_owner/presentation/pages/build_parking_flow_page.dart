import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:open_space_parking/core/common/exceptions/app_exception.dart';
import 'package:open_space_parking/core/providers/core_providers.dart';
import 'package:open_space_parking/core/routes/route_paths.dart';
import 'package:open_space_parking/core/widgets/buttons/primary_button.dart';
import 'package:open_space_parking/features/authentication/presentation/providers/auth_state_provider.dart';
import 'package:open_space_parking/core/utils/profile_prefill.dart';
import 'package:open_space_parking/features/land_owner/domain/entities/parking_preferences.dart';
import 'package:open_space_parking/features/land_owner/domain/entities/parking_type.dart';
import 'package:open_space_parking/features/land_owner/domain/entities/request_priority.dart';
import 'package:open_space_parking/features/land_owner/presentation/providers/land_owner_providers.dart';
import 'package:open_space_parking/features/notification/domain/entities/notification_recipient_type.dart';
import 'package:open_space_parking/features/notification/presentation/providers/notification_providers.dart';
import 'package:open_space_parking/features/land_owner/presentation/widgets/land_details_form.dart';
import 'package:open_space_parking/features/land_owner/presentation/widgets/land_owner_step_scaffold.dart';
import 'package:open_space_parking/features/land_owner/presentation/widgets/owner_details_form.dart';
import 'package:open_space_parking/features/land_owner/presentation/widgets/parking_type_carousel.dart';
import 'package:open_space_parking/features/land_owner/presentation/widgets/upload_documents_form.dart';

class BuildParkingFlowPage extends ConsumerStatefulWidget {
  const BuildParkingFlowPage({super.key});

  @override
  ConsumerState<BuildParkingFlowPage> createState() => _BuildParkingFlowPageState();
}

class _BuildParkingFlowPageState extends ConsumerState<BuildParkingFlowPage> {
  final _ownerFormKey = GlobalKey<OwnerDetailsFormState>();
  final _landFormKey = GlobalKey<LandDetailsFormState>();
  final _docsFormKey = GlobalKey<UploadDocumentsFormState>();
  final _carsController = TextEditingController(text: '1');
  final _rateController = TextEditingController();

  static const _stepLabels = [
    'Owner Details',
    'Upload Documents',
    'Land Details',
    'Parking Preferences',
    'Generate Ticket',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _seedOwnerDetails());
  }

  Future<void> _seedOwnerDetails() async {
    final ownerId = ref.read(authStateProvider).session?.userId;
    if (ownerId == null) return;

    final form = ref.read(buildParkingFormProvider);
    if (form.ownerDetails != null) return;

    final profile = await ref.read(landOwnerProfileProvider(ownerId).future);
    final session = ref.read(authStateProvider).session;
    final merged = ProfilePrefill.mergeOwnerDetails(
      saved: profile,
      accountDisplayName: session?.displayName,
      accountEmail: session?.email,
      session: session,
    );

    if (!ProfilePrefill.hasAnyOwnerDetails(merged)) return;
    if (!mounted) return;
    ref.read(buildParkingFormProvider.notifier).setOwnerDetails(merged);
  }

  @override
  void dispose() {
    _carsController.dispose();
    _rateController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final form = ref.read(buildParkingFormProvider);
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
      final request = await ref.read(landOwnerRepositoryProvider).submitBuildParkingRequest(
            ownerId: ownerId,
            ownerDetails: form.ownerDetails!,
            documents: form.documents,
            landDetails: form.landDetails!,
            parkingPreferences: ParkingPreferences(
              priority: form.priority,
              parkingType: form.parkingType,
              numberOfCars: form.numberOfCars,
              hourlyRate: form.hourlyRate,
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
    if (step == 1 && !(_docsFormKey.currentState?.isComplete ?? false)) {
      ref.read(snackbarServiceProvider).showError('Please upload all documents.');
      return;
    }
    if (step == 2 &&
        !await (_landFormKey.currentState?.validateAndSave() ?? Future.value(false))) {
      return;
    }
    if (step == 3) {
      final cars = int.tryParse(_carsController.text);
      if (cars == null || cars < 1) {
        ref.read(snackbarServiceProvider).showError('Enter valid number of cars.');
        return;
      }
      notifier.setNumberOfCars(cars);
    }

    notifier.nextStep();
  }

  @override
  Widget build(BuildContext context) {
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
          : Column(
              children: [
                if (form.generatedTicketId != null)
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.confirmation_number),
                      title: const Text('Ticket Generated'),
                      subtitle: Text(form.generatedTicketId!),
                    ),
                  ),
                const SizedBox(height: 12),
                PrimaryButton(
                  label: 'Submit to Admin',
                  isLoading: isLoading,
                  onPressed: _submit,
                ),
              ],
            ),
      child: _buildStepContent(form),
    );
  }

  Widget _buildStepContent(BuildParkingFormState form) {
    switch (form.currentStep) {
      case 0:
        return OwnerDetailsForm(
          key: _ownerFormKey,
          initial: form.ownerDetails,
          onSave: ref.read(buildParkingFormProvider.notifier).setOwnerDetails,
        );
      case 1:
        return UploadDocumentsForm(
          key: _docsFormKey,
          initial: form.documents,
          ownerId: ref.watch(authStateProvider).session?.userId ?? '',
          onChanged: ref.read(buildParkingFormProvider.notifier).setDocuments,
        );
      case 2:
        return LandDetailsForm(
          key: _landFormKey,
          initial: form.landDetails,
          onSave: ref.read(buildParkingFormProvider.notifier).setLandDetails,
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
              decoration: const InputDecoration(labelText: 'No of Cars / Slots'),
              keyboardType: TextInputType.number,
              onChanged: (v) {
                final count = int.tryParse(v.trim());
                if (count != null && count > 0) {
                  ref.read(buildParkingFormProvider.notifier).setNumberOfCars(count);
                }
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _rateController,
              decoration: const InputDecoration(
                labelText: 'Hourly Amount (₹)',
                hintText: 'Enter parking fee per hour',
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              onChanged: (v) {
                final rate = double.tryParse(v.trim());
                ref.read(buildParkingFormProvider.notifier).setHourlyRate(rate);
              },
            ),
          ],
        );
      case 4:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Review your request before submitting to admin.'),
            const SizedBox(height: 16),
            _ReviewTile('Owner', form.ownerDetails?.fullName ?? '-'),
            _ReviewTile('Email', form.ownerDetails?.email ?? '-'),
            _ReviewTile('Area', '${form.landDetails?.areaSqFt ?? 0} sq ft'),
            _ReviewTile('Priority', form.priority.label),
            _ReviewTile('Parking Type', form.parkingType.label),
            _ReviewTile('No of Cars', '${form.numberOfCars}'),
            _ReviewTile(
              'Hourly Amount',
              form.hourlyRate != null
                  ? '₹${form.hourlyRate!.toStringAsFixed(0)}/hr'
                  : 'Not set',
            ),
            const SizedBox(height: 16),
            FilledButton.tonalIcon(
              onPressed: () {
                final now = DateTime.now();
                final ticket =
                    'OSP-${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}-${DateTime.now().millisecondsSinceEpoch % 10000}';
                ref.read(buildParkingFormProvider.notifier).setGeneratedTicketId(ticket);
              },
              icon: const Icon(Icons.confirmation_number),
              label: const Text('Generate Ticket'),
            ),
          ],
        );
      default:
        return const SizedBox.shrink();
    }
  }
}

class _ReviewTile extends StatelessWidget {
  const _ReviewTile(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
