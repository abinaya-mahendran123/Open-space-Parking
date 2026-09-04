import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:open_space_parking/core/common/exceptions/app_exception.dart';
import 'package:open_space_parking/core/providers/core_providers.dart';
import 'package:open_space_parking/core/routes/route_paths.dart';
import 'package:open_space_parking/core/theme/app_colors.dart';
import 'package:open_space_parking/core/widgets/errors/app_error_widget.dart';
import 'package:open_space_parking/core/widgets/loading/app_loading_widget.dart';
import 'package:open_space_parking/core/widgets/textfields/app_text_field.dart';
import 'package:open_space_parking/features/authentication/presentation/providers/auth_state_provider.dart';
import 'package:open_space_parking/features/vehicle_owner/domain/entities/booking.dart';
import 'package:open_space_parking/features/vehicle_owner/domain/entities/parking_payment_split.dart';
import 'package:open_space_parking/features/vehicle_owner/presentation/providers/vehicle_owner_providers.dart';
import 'package:open_space_parking/features/vehicle_owner/presentation/utils/receipt_download_service.dart';
import 'package:open_space_parking/features/vehicle_owner/presentation/widgets/rating_stars.dart';

class ParkingReceiptPage extends ConsumerStatefulWidget {
  const ParkingReceiptPage({super.key, required this.bookingId});

  final String bookingId;

  @override
  ConsumerState<ParkingReceiptPage> createState() => _ParkingReceiptPageState();
}

class _ParkingReceiptPageState extends ConsumerState<ParkingReceiptPage> {
  bool _downloading = false;

  Future<void> _downloadReceipt(Booking booking) async {
    if (_downloading) return;
    setState(() => _downloading = true);
    try {
      final message = await ReceiptDownloadService.downloadReceipt(booking);
      if (!mounted) return;
      ref.read(snackbarServiceProvider).showSuccess(message);
    } catch (_) {
      if (mounted) {
        ref
            .read(snackbarServiceProvider)
            .showError('Could not download receipt. Try again.');
      }
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  Future<void> _review() async {
    final booking =
        await ref.read(bookingDetailProvider(widget.bookingId).future);
    if (booking == null || !mounted) return;

    var rating = 5;
    final comment = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Rate this parking'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              InteractiveRatingBar(
                rating: rating,
                onRatingChanged: (v) => setDialogState(() => rating = v),
              ),
              const SizedBox(height: 12),
              AppTextField(controller: comment, label: 'Comment (optional)'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Skip'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Submit'),
            ),
          ],
        ),
      ),
    );

    if (ok != true || !mounted) {
      comment.dispose();
      return;
    }

    final session = ref.read(authStateProvider).session;
    try {
      await ref.read(vehicleOwnerRepositoryProvider).submitReview(
            parkingListingId: booking.parkingListingId,
            vehicleOwnerId: session?.userId ?? booking.vehicleOwnerId,
            reviewerName: session?.email.split('@').first ?? 'Driver',
            rating: rating,
            comment: comment.text,
          );
      ref.invalidate(parkingReviewsProvider(booking.parkingListingId));
      ref.invalidate(parkingRatingSummaryProvider(booking.parkingListingId));
      ref.read(snackbarServiceProvider).showSuccess('Thanks for your review!');
    } on AppException catch (e) {
      ref.read(snackbarServiceProvider).showError(e.message);
    }
    comment.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bookingAsync = ref.watch(bookingDetailProvider(widget.bookingId));
    final format = DateFormat('dd MMM yyyy, hh:mm a');

    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: const Text('Receipt'),
        backgroundColor: colorScheme.surfaceContainer,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go(RoutePaths.vehicleOwnerBookings);
            }
          },
        ),
      ),
      body: bookingAsync.when(
        loading: () => const AppLoadingWidget(message: 'Loading receipt...'),
        error: (_, __) => AppErrorWidget(
          message: 'Could not load receipt',
          onRetry: () =>
              ref.invalidate(bookingDetailProvider(widget.bookingId)),
        ),
        data: (booking) {
          if (booking == null) {
            return const Center(child: Text('Receipt not found.'));
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Icon(
                Icons.check_circle,
                size: 64,
                color: AppColors.available,
              ),
              const SizedBox(height: 8),
              Text(
                'Payment successful',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 24),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      _row('Session ID', booking.displaySessionId),
                      _row('Parking', booking.displayParkingName),
                      _row('Vehicle', booking.vehicleNumber),
                      _row('Slot', '${booking.assignedSlot ?? '-'}'),
                      if (booking.checkedInAt != null)
                        _row('Check-in', format.format(booking.checkedInAt!.toLocal())),
                      if (booking.checkedOutAt != null)
                        _row('Check-out', format.format(booking.checkedOutAt!.toLocal())),
                      _row(
                        'Duration',
                        '${(booking.actualDurationHours ?? booking.durationHours).toStringAsFixed(2)} hrs',
                      ),
                      _row(
                        'Paid',
                        '₹${(booking.paidAmount ?? booking.totalPrice).toStringAsFixed(0)}',
                      ),
                      _row(
                        'Media account (10%)',
                        '₹${ParkingPaymentSplit.platformAmount(booking.paidAmount ?? booking.totalPrice).toStringAsFixed(0)}',
                      ),
                      _row(
                        'Land owner (90%)',
                        '₹${ParkingPaymentSplit.landOwnerAmount(booking.paidAmount ?? booking.totalPrice).toStringAsFixed(0)}',
                      ),
                      if (booking.paidAt != null)
                        _row('Paid at', format.format(booking.paidAt!.toLocal())),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _downloading ? null : () => _downloadReceipt(booking),
                icon: _downloading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.download_outlined),
                label: Text(_downloading ? 'Preparing...' : 'Download receipt'),
              ),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: _review,
                child: const Text('Leave a review'),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: () => context.go(RoutePaths.vehicleOwnerSearch),
                child: const Text('Find more parking'),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(label, style: Theme.of(context).textTheme.bodySmall),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
