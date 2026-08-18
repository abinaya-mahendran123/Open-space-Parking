import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:open_space_parking/core/common/exceptions/app_exception.dart';
import 'package:open_space_parking/core/domain/domain_extensions.dart';
import 'package:open_space_parking/core/providers/core_providers.dart';
import 'package:open_space_parking/core/routes/route_paths.dart';
import 'package:open_space_parking/core/widgets/buttons/primary_button.dart';
import 'package:open_space_parking/core/widgets/loading/app_loading_widget.dart';
import 'package:open_space_parking/core/widgets/textfields/app_text_field.dart';
import 'package:open_space_parking/features/authentication/presentation/providers/auth_state_provider.dart';
import 'package:open_space_parking/features/maps/domain/entities/directions_request.dart';
import 'package:open_space_parking/features/maps/domain/entities/map_coordinate.dart';
import 'package:open_space_parking/features/maps/presentation/providers/maps_providers.dart';
import 'package:open_space_parking/features/vehicle_owner/presentation/providers/vehicle_owner_providers.dart';

/// Arrive flow: open Google Maps navigation, enter plate, get slot + QR.
class ParkingCheckInPage extends ConsumerStatefulWidget {
  const ParkingCheckInPage({super.key, required this.listingId});

  final String listingId;

  @override
  ConsumerState<ParkingCheckInPage> createState() => _ParkingCheckInPageState();
}

class _ParkingCheckInPageState extends ConsumerState<ParkingCheckInPage> {
  final _plateController = TextEditingController();
  bool _navigating = false;
  bool _submitting = false;
  bool _mapsOpened = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _openMapsOnce());
  }

  @override
  void dispose() {
    _plateController.dispose();
    super.dispose();
  }

  Future<void> _openMapsOnce() async {
    if (_mapsOpened) return;
    final listing =
        await ref.read(parkingListingProvider(widget.listingId).future);
    if (listing == null || !mounted) return;

    setState(() => _navigating = true);
    final opened = await ref.read(mapsRepositoryProvider).openNavigation(
          DirectionsRequest(
            destination: MapCoordinate(
              latitude: listing.latitude,
              longitude: listing.longitude,
            ),
          ),
        );
    if (!mounted) return;
    setState(() {
      _navigating = false;
      _mapsOpened = true;
    });
    if (!opened) {
      ref
          .read(snackbarServiceProvider)
          .showError('Could not open Google Maps. Continue to check in.');
    } else {
      ref
          .read(snackbarServiceProvider)
          .showSuccess('Navigation started. Arrive and enter your plate.');
    }

    final profileId = ref.read(authStateProvider).session?.userId;
    if (profileId != null) {
      final profile =
          await ref.read(vehicleOwnerProfileProvider(profileId).future);
      final plate = profile?.vehicleNumber;
      if (plate != null && plate.isNotEmpty && mounted) {
        _plateController.text = plate;
      }
    }
  }

  Future<void> _startSession() async {
    final ownerId = ref.read(authStateProvider).session?.userId;
    if (ownerId == null) {
      ref.read(snackbarServiceProvider).showError('Please sign in again.');
      return;
    }

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
      context.go(RoutePaths.vehicleOwnerParkingTicket(booking.id));
    } on AppException catch (e) {
      ref.read(snackbarServiceProvider).showError(e.message);
    } catch (_) {
      ref.read(snackbarServiceProvider).showError('Could not start session.');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final listingAsync = ref.watch(parkingListingProvider(widget.listingId));

    return Scaffold(
      appBar: AppBar(title: const Text('Arrive & Check In')),
      body: listingAsync.when(
        loading: () => const AppLoadingWidget(message: 'Loading parking...'),
        error: (_, __) => const Center(child: Text('Parking not found.')),
        data: (listing) {
          if (listing == null) {
            return const Center(child: Text('Parking not found.'));
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                listing.parkingType.label,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 4),
              Text(listing.locationLabel),
              const SizedBox(height: 16),
              Card(
                child: ListTile(
                  leading: Icon(
                    _mapsOpened ? Icons.navigation : Icons.hourglass_top,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  title: Text(
                    _navigating
                        ? 'Opening Google Maps...'
                        : _mapsOpened
                            ? 'Navigation opened'
                            : 'Starting navigation',
                  ),
                  subtitle: const Text(
                    'Drive to the parking. When you arrive, enter your car number below.',
                  ),
                  trailing: TextButton(
                    onPressed: _navigating ? null : _openMapsOnce,
                    child: const Text('Re-open'),
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
                label: 'e.g. TN 09 AB 1234',
              ),
              const SizedBox(height: 8),
              Text(
                'You will automatically get the first free slot and a QR ticket.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 24),
              PrimaryButton(
                label: _submitting ? 'Assigning slot...' : 'I\'ve Arrived — Get Slot',
                onPressed: _submitting ? null : _startSession,
              ),
            ],
          );
        },
      ),
    );
  }
}
