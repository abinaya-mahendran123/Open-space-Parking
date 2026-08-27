import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import 'package:open_space_parking/core/common/exceptions/app_exception.dart';
import 'package:open_space_parking/core/config/environment_config.dart';
import 'package:open_space_parking/core/providers/core_providers.dart';
import 'package:open_space_parking/core/routes/route_paths.dart';
import 'package:open_space_parking/core/widgets/buttons/primary_button.dart';
import 'package:open_space_parking/core/widgets/errors/app_error_widget.dart';
import 'package:open_space_parking/core/widgets/loading/app_loading_widget.dart';
import 'package:open_space_parking/features/authentication/presentation/providers/auth_state_provider.dart';
import 'package:open_space_parking/features/vehicle_owner/domain/entities/booking_status.dart';
import 'package:open_space_parking/features/vehicle_owner/domain/entities/parking_payment_split.dart';
import 'package:open_space_parking/features/vehicle_owner/presentation/providers/vehicle_owner_providers.dart';

class ParkingPaymentPage extends ConsumerStatefulWidget {
  const ParkingPaymentPage({super.key, required this.bookingId});

  final String bookingId;

  @override
  ConsumerState<ParkingPaymentPage> createState() => _ParkingPaymentPageState();
}

class _ParkingPaymentPageState extends ConsumerState<ParkingPaymentPage> {
  bool _paying = false;
  bool _checking = false;

  Future<Map<String, dynamic>> _createOrder() async {
    final uri = Uri.parse(
      '${EnvironmentConfig.baseApiUrl}/api/payments/razorpay/create-order',
    );
    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'bookingId': widget.bookingId}),
    );
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode >= 400) {
      throw AppException(
        body['error']?.toString() ?? 'Could not start Razorpay',
      );
    }
    return body;
  }

  Future<void> _payWithRazorpay() async {
    setState(() => _paying = true);
    try {
      final order = await _createOrder();
      final orderAmount = (order['amount'] as num?)?.toDouble() ?? 0;
      // Server may repair a ₹0 bill (missing hourly rate). Refresh local booking.
      ref.invalidate(bookingDetailProvider(widget.bookingId));

      if (orderAmount < 1) {
        await _completeNoCharge();
        return;
      }

      var checkoutUrl = order['checkoutUrl']?.toString();
      if (checkoutUrl == null || checkoutUrl.isEmpty) {
        throw const AppException('Razorpay checkout URL missing');
      }
      if (checkoutUrl.startsWith('/')) {
        checkoutUrl = '${EnvironmentConfig.baseApiUrl}$checkoutUrl';
      }

      final opened = await launchUrl(
        Uri.parse(checkoutUrl),
        mode: LaunchMode.externalApplication,
      );
      if (!opened) {
        throw const AppException('Could not open Razorpay checkout');
      }

      ref.read(snackbarServiceProvider).showSuccess(
            'Complete payment in Razorpay, then tap “I’ve paid”.',
          );
    } on AppException catch (e) {
      ref.read(snackbarServiceProvider).showError(e.message);
    } catch (_) {
      ref.read(snackbarServiceProvider).showError('Could not open Razorpay.');
    } finally {
      if (mounted) setState(() => _paying = false);
    }
  }

  Future<void> _completeNoCharge() async {
    setState(() => _paying = true);
    try {
      await ref.read(vehicleOwnerRepositoryProvider).payAndCompleteBooking(
            bookingId: widget.bookingId,
            paymentMethod: 'No charge',
          );
      final ownerId = ref.read(authStateProvider).session?.userId;
      if (ownerId != null) {
        ref.invalidate(vehicleOwnerBookingsProvider(ownerId));
      }
      ref.invalidate(bookingDetailProvider(widget.bookingId));
      ref.invalidate(parkingListingsProvider);
      if (!mounted) return;
      context.go(RoutePaths.vehicleOwnerBookingReceipt(widget.bookingId));
    } on AppException catch (e) {
      ref.read(snackbarServiceProvider).showError(e.message);
    } catch (_) {
      ref.read(snackbarServiceProvider).showError('Could not complete checkout.');
    } finally {
      if (mounted) setState(() => _paying = false);
    }
  }

  Future<void> _confirmPaid() async {
    setState(() => _checking = true);
    try {
      final uri = Uri.parse(
        '${EnvironmentConfig.baseApiUrl}/api/payments/razorpay/confirm',
      );
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'bookingId': widget.bookingId}),
      );
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode >= 400) {
        throw AppException(
          body['error']?.toString() ??
              'Payment not received yet. Finish Razorpay, then try again.',
        );
      }

      final ownerId = ref.read(authStateProvider).session?.userId;
      if (ownerId != null) {
        ref.invalidate(vehicleOwnerBookingsProvider(ownerId));
      }
      ref.invalidate(bookingDetailProvider(widget.bookingId));
      ref.invalidate(parkingListingsProvider);
      if (!mounted) return;
      context.go(RoutePaths.vehicleOwnerBookingReceipt(widget.bookingId));
    } on AppException catch (e) {
      ref.read(snackbarServiceProvider).showError(e.message);
    } catch (_) {
      ref.read(snackbarServiceProvider).showError('Could not confirm payment.');
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bookingAsync = ref.watch(bookingDetailProvider(widget.bookingId));

    return Scaffold(
      appBar: AppBar(title: const Text('Pay with Razorpay')),
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
          if (booking.paidAt != null ||
              booking.status == BookingStatus.completed) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Payment already completed.'),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: () => context.go(
                        RoutePaths.vehicleOwnerBookingReceipt(booking.id),
                      ),
                      child: const Text('View receipt'),
                    ),
                  ],
                ),
              ),
            );
          }
          if (!booking.isAwaitingPayment) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Ask security to scan your QR at exit first. '
                  'Amount is calculated from parking duration.',
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
                '${booking.billedDurationLabel} × ₹${booking.hourlyRate.toStringAsFixed(0)}/hr',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      _billRow('Parking', booking.displayParkingName),
                      _billRow('Slot no', '${booking.assignedSlot ?? '-'}'),
                      _billRow('Session ID', booking.displaySessionId),
                      _billRow('Vehicle', booking.vehicleNumber),
                      _billRow('Duration', booking.billedDurationLabel),
                      _billRow('Amount', '₹${amount.toStringAsFixed(0)}'),
                      _billRow(
                        ParkingPaymentSplit.platformAccountName,
                        '₹${ParkingPaymentSplit.platformAmount(amount).toStringAsFixed(0)} (10%)',
                      ),
                      _billRow(
                        ParkingPaymentSplit.landOwnerShareLabel,
                        '₹${ParkingPaymentSplit.landOwnerAmount(amount).toStringAsFixed(0)} (90%)',
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    amount < 1
                        ? 'No parking fee for this session. Complete checkout to release the slot.'
                        : 'Pay the full amount with Razorpay (UPI / card / netbanking). '
                            '10% is kept by the Open Space Parking media account and '
                            '90% is settled to the land owner.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              PrimaryButton(
                label: _paying
                    ? 'Opening Razorpay...'
                    : amount < 1
                        ? 'Calculate fee & pay with Razorpay'
                        : 'Pay ₹${amount.toStringAsFixed(0)} with Razorpay',
                onPressed: _paying ? null : _payWithRazorpay,
              ),
              if (amount >= 1) ...[
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: _checking ? null : _confirmPaid,
                  child: Text(_checking ? 'Checking...' : 'I’ve paid — continue'),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _billRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
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
