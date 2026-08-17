import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:open_space_parking/core/common/exceptions/app_exception.dart';
import 'package:open_space_parking/core/domain/domain_extensions.dart';
import 'package:open_space_parking/core/providers/core_providers.dart';
import 'package:open_space_parking/core/routes/route_paths.dart';
import 'package:open_space_parking/core/utils/validators.dart';
import 'package:open_space_parking/core/widgets/buttons/primary_button.dart';
import 'package:open_space_parking/core/widgets/loading/app_loading_widget.dart';
import 'package:open_space_parking/core/widgets/textfields/app_text_field.dart';
import 'package:open_space_parking/features/authentication/presentation/providers/auth_state_provider.dart';
import 'package:open_space_parking/features/vehicle_owner/presentation/providers/vehicle_owner_providers.dart';
import 'package:open_space_parking/features/vehicle_owner/presentation/widgets/slot_booked_dialog.dart';

/// Arrive at parking → enter plate → FCFS slot + QR (session starts on security scan).
class ParkingCheckInPage extends ConsumerStatefulWidget {
  const ParkingCheckInPage({super.key, required this.listingId});

  final String listingId;

  @override
  ConsumerState<ParkingCheckInPage> createState() => _ParkingCheckInPageState();
}

class _ParkingCheckInPageState extends ConsumerState<ParkingCheckInPage> {
  final _formKey = GlobalKey<FormState>();
  final _plateController = TextEditingController();
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _prefillPlate());
  }

  @override
  void dispose() {
    _plateController.dispose();
    super.dispose();
  }

  Future<void> _prefillPlate() async {
    final profileId = ref.read(authStateProvider).session?.userId;
    if (profileId == null) return;
    final profile =
        await ref.read(vehicleOwnerProfileProvider(profileId).future);
    final plate = profile?.vehicleNumber;
    if (plate != null && plate.isNotEmpty && mounted) {
      _plateController.text = plate;
    }
  }

  Future<void> _bookSlot() async {
    final ownerId = ref.read(authStateProvider).session?.userId;
    if (ownerId == null) {
      ref.read(snackbarServiceProvider).showError('Please sign in again.');
      return;
    }
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _submitting = true);
    try {
      final booking =
          await ref.read(vehicleOwnerRepositoryProvider).startParkingSession(
                vehicleOwnerId: ownerId,
                parkingListingId: widget.listingId,
                vehicleNumber: _plateController.text,
              );
      ref.invalidate(parkingListingsProvider);
      ref.invalidate(parkingAvailabilityProvider(widget.listingId));
      ref.invalidate(vehicleOwnerBookingsProvider(ownerId));
      if (!mounted) return;
      final listing =
          await ref.read(parkingListingProvider(widget.listingId).future);
      if (!mounted) return;
      await showSlotBookedDialog(
        context,
        slot: booking.assignedSlot ?? 0,
        parkingName: listing?.displayName ?? 'this parking',
      );
      if (!mounted) return;
      context.go(RoutePaths.vehicleOwnerParkingTicket(booking.id));
    } on AppException catch (e) {
      ref.read(snackbarServiceProvider).showError(e.message);
    } catch (_) {
      ref.read(snackbarServiceProvider).showError('Could not book a slot.');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final listingAsync = ref.watch(parkingListingProvider(widget.listingId));

    return Scaffold(
      appBar: AppBar(title: const Text('Book Parking Slot')),
      body: listingAsync.when(
        loading: () => const AppLoadingWidget(message: 'Loading parking...'),
        error: (_, __) => const Center(child: Text('Parking not found.')),
        data: (listing) {
          if (listing == null) {
            return const Center(child: Text('Parking not found.'));
          }
          return Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  listing.displayName,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 4),
                Text(listing.parkingType.label),
                if (listing.amountLabel != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    listing.amountLabel!,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                        ),
                  ),
                ],
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      '1. Book a slot (first come, first served)\n'
                      '2. Show the QR to security to start parking\n'
                      '3. Show the same QR again when you leave\n'
                      '4. Pay the calculated amount with Razorpay',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Vehicle number',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                AppTextField(
                  controller: _plateController,
                  label: 'Vehicle number',
                  hint: 'TN 09 AB 1234',
                  textCapitalization: TextCapitalization.characters,
                  inputFormatters: Validators.vehicleNumberFormatters,
                  validator: Validators.vehicleNumber,
                ),
                const SizedBox(height: 24),
                PrimaryButton(
                  label: _submitting ? 'Assigning slot...' : 'Book Slot',
                  onPressed: _submitting ? null : _bookSlot,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
