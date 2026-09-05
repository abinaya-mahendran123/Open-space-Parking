import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:open_space_parking/core/domain/domain_extensions.dart';
import 'package:open_space_parking/core/common/exceptions/app_exception.dart';
import 'package:open_space_parking/core/providers/core_providers.dart';
import 'package:open_space_parking/core/routes/route_paths.dart';
import 'package:open_space_parking/core/utils/validators.dart';
import 'package:open_space_parking/core/widgets/buttons/primary_button.dart';
import 'package:open_space_parking/core/widgets/errors/app_error_widget.dart';
import 'package:open_space_parking/core/widgets/loading/app_loading_widget.dart';
import 'package:open_space_parking/core/widgets/textfields/app_text_field.dart';
import 'package:open_space_parking/features/authentication/presentation/providers/auth_state_provider.dart';
import 'package:open_space_parking/features/land_owner/presentation/widgets/land_owner_step_scaffold.dart';
import 'package:open_space_parking/features/vehicle_owner/domain/entities/parking_availability.dart';
import 'package:open_space_parking/features/vehicle_owner/domain/entities/parking_listing.dart';
import 'package:open_space_parking/features/vehicle_owner/domain/entities/vehicle_owner_profile.dart';
import 'package:open_space_parking/features/vehicle_owner/presentation/providers/vehicle_owner_providers.dart';
import 'package:open_space_parking/features/notification/domain/entities/notification_recipient_type.dart';
import 'package:open_space_parking/features/notification/presentation/providers/notification_providers.dart';
import 'package:open_space_parking/features/vehicle_owner/presentation/widgets/availability_chip.dart';

class BookingFlowPage extends ConsumerStatefulWidget {
  const BookingFlowPage({super.key, required this.listingId});

  final String listingId;

  @override
  ConsumerState<BookingFlowPage> createState() => _BookingFlowPageState();
}

class _BookingFlowPageState extends ConsumerState<BookingFlowPage> {
  static final _dateFormat = DateFormat('dd MMM yyyy, hh:mm a');

  final _vehicleFormKey = GlobalKey<FormState>();
  final _vehicleNumberController = TextEditingController();
  final _vehicleModelController = TextEditingController();
  bool _submitting = false;
  bool _checkingAvailability = false;
  ParkingAvailability? _availability;

  static const _stepLabels = ['Schedule', 'Vehicle', 'Confirm'];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(bookingFormProvider.notifier).init(widget.listingId);
      _prefillVehicleFromProfile();
    });
  }

  Future<void> _prefillVehicleFromProfile() async {
    final ownerId = ref.read(authStateProvider).session?.userId;
    if (ownerId == null || ownerId.isEmpty) return;
    try {
      final profile =
          await ref.read(vehicleOwnerProfileProvider(ownerId).future);
      final number = profile?.vehicleNumber?.trim() ?? '';
      final model = profile?.vehicleModel?.trim() ?? '';
      if (!mounted) return;
      if (number.isNotEmpty && _vehicleNumberController.text.isEmpty) {
        _vehicleNumberController.text = number;
        ref.read(bookingFormProvider.notifier).setVehicleNumber(number);
      }
      if (model.isNotEmpty && _vehicleModelController.text.isEmpty) {
        _vehicleModelController.text = model;
        ref.read(bookingFormProvider.notifier).setVehicleModel(model);
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _vehicleNumberController.dispose();
    _vehicleModelController.dispose();
    super.dispose();
  }

  Future<void> _pickDateTime({required bool isStart}) async {
    final form = ref.read(bookingFormProvider);
    final now = DateTime.now();
    final initialDate = isStart
        ? (form.startDateTime ?? now.add(const Duration(hours: 1)))
        : (form.endDateTime ?? now.add(const Duration(hours: 3)));

    final date = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: now,
      lastDate: now.add(const Duration(days: 90)),
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initialDate),
    );
    if (time == null || !mounted) return;

    final selected = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );

    final notifier = ref.read(bookingFormProvider.notifier);
    if (isStart) {
      final end = form.endDateTime;
      notifier.setSchedule(selected, end ?? selected.add(const Duration(hours: 2)));
    } else {
      final start = form.startDateTime ?? selected.subtract(const Duration(hours: 2));
      notifier.setSchedule(start, selected);
    }
  }

  Future<void> _checkAvailability() async {
    final form = ref.read(bookingFormProvider);
    if (form.startDateTime == null || form.endDateTime == null) {
      ref.read(snackbarServiceProvider).showError('Select start and end time first.');
      return;
    }

    setState(() => _checkingAvailability = true);
    try {
      final availability = await ref
          .read(vehicleOwnerRepositoryProvider)
          .checkAvailability(
            parkingListingId: widget.listingId,
            startDateTime: form.startDateTime!,
            endDateTime: form.endDateTime!,
          );
      ref.read(bookingFormProvider.notifier).setAvailabilityResult(
            availability.isAvailable,
          );
      setState(() => _availability = availability);
    } on AppException catch (e) {
      ref.read(snackbarServiceProvider).showError(e.message);
    } finally {
      if (mounted) setState(() => _checkingAvailability = false);
    }
  }

  Future<void> _submit(String vehicleOwnerId) async {
    final form = ref.read(bookingFormProvider);
    if (form.startDateTime == null || form.endDateTime == null) {
      ref.read(snackbarServiceProvider).showError('Please select start and end time.');
      return;
    }

    setState(() => _submitting = true);
    try {
      final booking = await ref.read(vehicleOwnerRepositoryProvider).createBooking(
            vehicleOwnerId: vehicleOwnerId,
            parkingListingId: widget.listingId,
            vehicleNumber: form.vehicleNumber,
            vehicleModel: form.vehicleModel.isEmpty ? null : form.vehicleModel,
            startDateTime: form.startDateTime!,
            endDateTime: form.endDateTime!,
          );

      ref.invalidate(vehicleOwnerBookingsProvider(vehicleOwnerId));
      await _rememberVehicleOnProfile(
        vehicleOwnerId: vehicleOwnerId,
        vehicleNumber: form.vehicleNumber,
        vehicleModel: form.vehicleModel,
      );
      invalidateNotificationCache(
        ref,
        recipientId: vehicleOwnerId,
        recipientType: NotificationRecipientType.vehicleOwner,
      );
      ref.invalidate(vehicleOwnerUnreadCountProvider(vehicleOwnerId));
      ref.read(bookingFormProvider.notifier).reset();
      ref.read(snackbarServiceProvider).showSuccess('Booking confirmed!');
      if (mounted) {
        context.push(RoutePaths.vehicleOwnerBookingDetail(booking.id));
      }
    } on AppException catch (e) {
      ref.read(snackbarServiceProvider).showError(e.message);
    } catch (_) {
      ref.read(snackbarServiceProvider).showError('Could not create booking.');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _rememberVehicleOnProfile({
    required String vehicleOwnerId,
    required String vehicleNumber,
    required String vehicleModel,
  }) async {
    try {
      final repo = ref.read(vehicleOwnerRepositoryProvider);
      final saved = await repo.getProfile(vehicleOwnerId);
      await repo.updateProfile(
        vehicleOwnerId: vehicleOwnerId,
        profile: VehicleOwnerProfile(
          fullName: saved?.fullName ?? '',
          phone: saved?.phone ?? '',
          vehicleNumber: vehicleNumber.trim().toUpperCase(),
          vehicleModel: vehicleModel.trim().isEmpty
              ? saved?.vehicleModel
              : vehicleModel.trim(),
          vehicleBrand: saved?.vehicleBrand,
          vehicleLengthM: saved?.vehicleLengthM,
          vehicleWidthM: saved?.vehicleWidthM,
          vehicleParkingClass: saved?.vehicleParkingClass,
        ),
      );
      ref.invalidate(vehicleOwnerProfileProvider(vehicleOwnerId));
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final form = ref.watch(bookingFormProvider);
    final listingAsync = ref.watch(parkingListingProvider(widget.listingId));
    final vehicleOwnerId = ref.watch(authStateProvider).session?.userId ?? '';

    return listingAsync.when(
      loading: () => const Scaffold(
        body: AppLoadingWidget(message: 'Loading parking space...'),
      ),
      error: (_, __) => Scaffold(
        appBar: AppBar(),
        body: AppErrorWidget(
          message: 'Could not load parking space',
          onRetry: () => ref.invalidate(parkingListingProvider(widget.listingId)),
        ),
      ),
      data: (listing) {
        if (listing == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const Center(child: Text('Parking space not found.')),
          );
        }

        final estimated = estimatedBookingPrice(listing, form);

        return LandOwnerStepScaffold(
          title: 'Book Parking',
          currentStep: form.currentStep,
          totalSteps: BookingFormState.totalSteps,
          stepLabels: _stepLabels,
          onBack: form.currentStep > 0
              ? () => ref.read(bookingFormProvider.notifier).previousStep()
              : () => context.pop(),
          bottomBar: _buildBottomBar(form, listing, vehicleOwnerId, estimated),
          child: _buildStepContent(form, listing, _dateFormat, estimated),
        );
      },
    );
  }

  Widget _buildStepContent(
    BookingFormState form,
    ParkingListing listing,
    DateFormat dateFormat,
    double? estimated,
  ) {
    switch (form.currentStep) {
      case 0:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              listing.parkingType.label,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Start'),
              subtitle: Text(
                form.startDateTime != null
                    ? _dateFormat.format(form.startDateTime!.toLocal())
                    : 'Not selected',
              ),
              trailing: const Icon(Icons.calendar_today),
              onTap: () => _pickDateTime(isStart: true),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('End'),
              subtitle: Text(
                form.endDateTime != null
                    ? _dateFormat.format(form.endDateTime!.toLocal())
                    : 'Not selected',
              ),
              trailing: const Icon(Icons.calendar_today),
              onTap: () => _pickDateTime(isStart: false),
            ),
            if (estimated != null) ...[
              const SizedBox(height: 16),
              Text(
                'Estimated total: ₹${estimated.toStringAsFixed(0)}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ],
            const SizedBox(height: 16),
            FilledButton.tonalIcon(
              onPressed: _checkingAvailability ? null : _checkAvailability,
              icon: _checkingAvailability
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.event_available),
              label: const Text('Check Availability'),
            ),
            if (_availability != null) ...[
              const SizedBox(height: 12),
              AvailabilityChip(availability: _availability!),
            ],
          ],
        );
      case 1:
        return Form(
          key: _vehicleFormKey,
          child: Column(
            children: [
              AppTextField(
                controller: _vehicleNumberController,
                label: 'Vehicle Number',
                hint: 'TN 09 AB 1234',
                textCapitalization: TextCapitalization.characters,
                inputFormatters: Validators.vehicleNumberFormatters,
                validator: Validators.vehicleNumber,
              ),
              const SizedBox(height: 12),
              AppTextField(
                controller: _vehicleModelController,
                label: 'Vehicle Model (optional)',
              ),
            ],
          ),
        );
      case 2:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Booking Summary', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            _SummaryRow(label: 'Parking', value: listing.parkingType.label),
            _SummaryRow(label: 'Location', value: listing.locationLabel),
            _SummaryRow(
              label: 'Start',
              value: form.startDateTime != null
                  ? _dateFormat.format(form.startDateTime!.toLocal())
                  : '-',
            ),
            _SummaryRow(
              label: 'End',
              value: form.endDateTime != null
                  ? _dateFormat.format(form.endDateTime!.toLocal())
                  : '-',
            ),
            _SummaryRow(
              label: 'Vehicle',
              value: form.vehicleNumber.isEmpty ? '-' : form.vehicleNumber,
            ),
            const Divider(height: 32),
            _SummaryRow(
              label: 'Total',
              value: estimated != null ? '₹${estimated.toStringAsFixed(0)}' : '-',
              emphasized: true,
            ),
          ],
        );
      default:
        return const SizedBox.shrink();
    }
  }

  Widget? _buildBottomBar(
    BookingFormState form,
    ParkingListing listing,
    String vehicleOwnerId,
    double? estimated,
  ) {
    if (form.currentStep == 0) {
      final canContinue = form.startDateTime != null &&
          form.endDateTime != null &&
          estimated != null &&
          form.availabilityChecked &&
          form.isAvailable;
      return PrimaryButton(
        label: 'Continue',
        onPressed: canContinue
            ? () => ref.read(bookingFormProvider.notifier).nextStep()
            : null,
      );
    }

    if (form.currentStep == 1) {
      return PrimaryButton(
        label: 'Continue',
        onPressed: () {
          if (_vehicleFormKey.currentState!.validate()) {
            ref.read(bookingFormProvider.notifier)
              ..setVehicleNumber(_vehicleNumberController.text.trim())
              ..setVehicleModel(_vehicleModelController.text.trim())
              ..nextStep();
          }
        },
      );
    }

    return PrimaryButton(
      label: 'Confirm Booking',
      isLoading: _submitting,
      onPressed: _submitting ? null : () => _submit(vehicleOwnerId),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.label,
    required this.value,
    this.emphasized = false,
  });

  final String label;
  final String value;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final style = emphasized
        ? Theme.of(context).textTheme.titleMedium
        : Theme.of(context).textTheme.bodyLarge;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodyMedium),
          Flexible(
            child: Text(
              value,
              style: style,
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }
}
