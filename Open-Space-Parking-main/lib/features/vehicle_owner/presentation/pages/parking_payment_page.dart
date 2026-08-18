import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:open_space_parking/core/common/exceptions/app_exception.dart';
import 'package:open_space_parking/core/domain/domain_extensions.dart';
import 'package:open_space_parking/core/providers/core_providers.dart';
import 'package:open_space_parking/core/routes/route_paths.dart';
import 'package:open_space_parking/core/widgets/buttons/primary_button.dart';
import 'package:open_space_parking/core/widgets/errors/app_error_widget.dart';
import 'package:open_space_parking/core/widgets/loading/app_loading_widget.dart';
import 'package:open_space_parking/features/authentication/presentation/providers/auth_state_provider.dart';
import 'package:open_space_parking/features/vehicle_owner/presentation/providers/vehicle_owner_providers.dart';

class ParkingPaymentPage extends ConsumerStatefulWidget {
  const ParkingPaymentPage({super.key, required this.bookingId});

  final String bookingId;

  @override
  ConsumerState<ParkingPaymentPage> createState() => _ParkingPaymentPageState();
}

class _ParkingPaymentPageState extends ConsumerState<ParkingPaymentPage> {
  String _method = 'UPI';
  bool _paying = false;

  Future<void> _pay() async {
    setState(() => _paying = true);
    try {
      final booking = await ref
          .read(vehicleOwnerRepositoryProvider)
          .payAndCompleteBooking(
            bookingId: widget.bookingId,
            paymentMethod: _method,
          );
      final ownerId = ref.read(authStateProvider).session?.userId;
      if (ownerId != null) {
        ref.invalidate(vehicleOwnerBookingsProvider(ownerId));
      }
      ref.invalidate(bookingDetailProvider(widget.bookingId));
      ref.invalidate(parkingListingsProvider);
      if (!mounted) return;
      context.go(RoutePaths.vehicleOwnerBookingReceipt(booking.id));
    } on AppException catch (e) {
      ref.read(snackbarServiceProvider).showError(e.message);
    } catch (_) {
      ref.read(snackbarServiceProvider).showError('Payment failed.');
    } finally {
      if (mounted) setState(() => _paying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bookingAsync = ref.watch(bookingDetailProvider(widget.bookingId));

    return Scaffold(
      appBar: AppBar(title: const Text('Pay & Checkout')),
      body: bookingAsync.when(
        loading: () => const AppLoadingWidget(message: 'Loading bill...'),
        error: (_, __) => AppErrorWidget(
          message: 'Could not load bill',
          onRetry: () =>
              ref.invalidate(bookingDetailProvider(widget.bookingId)),
        ),
        data: (booking) {
          if (booking == null) {
            return const Center(child: Text('Booking not found.'));
          }
          if (!booking.isAwaitingPayment) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  booking.status.label == 'Completed'
                      ? 'Already paid. Open receipt from bookings.'
                      : 'Ask security to scan your QR first.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final amount = booking.amountDue!;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                '₹${amount.toStringAsFixed(0)}',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.displaySmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                '${(booking.actualDurationHours ?? 0).toStringAsFixed(2)} hrs × ₹${booking.hourlyRate.toStringAsFixed(0)}/hr',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Text('Payment method',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  for (final method in ['UPI', 'Card', 'Cash'])
                    ChoiceChip(
                      label: Text(method),
                      selected: _method == method,
                      onSelected: (_) => setState(() => _method = method),
                    ),
                ],
              ),
              const SizedBox(height: 24),
              PrimaryButton(
                label: _paying
                    ? 'Processing...'
                    : 'Pay ₹${amount.toStringAsFixed(0)} & Release Slot',
                onPressed: _paying ? null : _pay,
              ),
            ],
          );
        },
      ),
    );
  }
}
