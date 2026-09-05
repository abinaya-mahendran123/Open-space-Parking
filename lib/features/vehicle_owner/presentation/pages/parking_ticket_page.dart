import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'package:open_space_parking/core/domain/domain_extensions.dart';
import 'package:open_space_parking/core/routes/route_paths.dart';
import 'package:open_space_parking/core/theme/app_colors.dart';
import 'package:open_space_parking/core/theme/app_spacing.dart';
import 'package:open_space_parking/core/widgets/brand/app_brand_logo.dart';
import 'package:open_space_parking/core/widgets/errors/app_error_widget.dart';
import 'package:open_space_parking/core/widgets/loading/app_loading_widget.dart';
import 'package:open_space_parking/features/vehicle_owner/domain/entities/booking.dart';
import 'package:open_space_parking/features/vehicle_owner/domain/entities/booking_status.dart';
import 'package:open_space_parking/features/vehicle_owner/presentation/providers/vehicle_owner_providers.dart';

class ParkingTicketPage extends ConsumerStatefulWidget {
  const ParkingTicketPage({super.key, required this.bookingId});

  final String bookingId;

  @override
  ConsumerState<ParkingTicketPage> createState() => _ParkingTicketPageState();
}

class _ParkingTicketPageState extends ConsumerState<ParkingTicketPage> {
  Timer? _pollTimer;
  Timer? _tickTimer;
  final ValueNotifier<DateTime> _now = ValueNotifier(DateTime.now());

  @override
  void initState() {
    super.initState();
    _pollTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted) return;
      final booking = ref.read(bookingDetailProvider(widget.bookingId)).valueOrNull;
      if (booking != null &&
          (booking.status == BookingStatus.completed ||
              booking.status == BookingStatus.cancelled)) {
        return;
      }
      // When entry QR times out client-side, refresh so UI / server cancel sync.
      if (booking != null &&
          booking.status == BookingStatus.confirmed &&
          booking.checkedInAt == null &&
          booking.isEntryQrExpired) {
        ref.invalidate(bookingDetailProvider(widget.bookingId));
        final ownerId = booking.vehicleOwnerId;
        if (ownerId.isNotEmpty) {
          ref.invalidate(vehicleOwnerBookingsProvider(ownerId));
        }
        return;
      }
      ref.invalidate(bookingDetailProvider(widget.bookingId));
    });
    _tickTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      _now.value = DateTime.now();
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _tickTimer?.cancel();
    _now.dispose();
    super.dispose();
  }

  String _statusHint(Booking booking) {
    if (booking.isAwaitingPayment) return 'Pay to release your slot';
    if (booking.isParked) return 'Show this QR when you leave';
    if (booking.showEntryQrCountdown && booking.isEntryQrExpired) {
      return 'Entry QR expired. Book a new slot.';
    }
    if (booking.showEntryQrCountdown) {
      return 'Show this QR at the gate · valid 2 hours from booking';
    }
    if (booking.status == BookingStatus.completed) return 'Payment complete';
    if (booking.status == BookingStatus.cancelled) {
      return 'Booking cancelled';
    }
    return 'Show this QR to security';
  }

  String _statusLabel(Booking booking) {
    if (booking.isAwaitingPayment) return 'Payment due';
    if (booking.isParked) return 'Active';
    if (booking.showEntryQrCountdown && booking.isEntryQrExpired) {
      return 'QR expired';
    }
    if (booking.showEntryQrCountdown || booking.isAwaitingEntry) {
      return 'Awaiting entry';
    }
    if (booking.status == BookingStatus.completed) return 'Completed';
    return booking.status.label;
  }

  Color _statusColor(Booking booking) {
    if (booking.isAwaitingPayment) return AppColors.brandAmber;
    if (booking.showEntryQrCountdown && booking.isEntryQrExpired) {
      return Theme.of(context).colorScheme.error;
    }
    if (booking.isParked ||
        booking.isAwaitingEntry ||
        booking.showEntryQrCountdown) {
      return AppColors.brandMint;
    }
    if (booking.status == BookingStatus.completed) {
      return AppColors.brandBlue;
    }
    return Theme.of(context).colorScheme.primary;
  }

  @override
  Widget build(BuildContext context) {
    final bookingAsync = ref.watch(bookingDetailProvider(widget.bookingId));
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isLight = theme.brightness == Brightness.light;

    return Scaffold(
      backgroundColor: isLight ? AppColors.lightBackground : colorScheme.surface,
      appBar: AppBar(
        title: const Text('Parking pass'),
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
        loading: () => const AppLoadingWidget(message: 'Loading...'),
        error: (_, __) => AppErrorWidget(
          message: 'Could not load ticket',
          onRetry: () => ref.invalidate(bookingDetailProvider(widget.bookingId)),
        ),
        data: (booking) {
          if (booking == null) {
            return const Center(child: Text('Ticket not found.'));
          }

          final statusColor = _statusColor(booking);

          return ListView(
            padding: const EdgeInsets.all(AppSpacing.md),
            children: [
              _ParkingPassCard(
                child: Column(
                  children: [
                    Text(
                      'PARKING PASS',
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        letterSpacing: 2,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    const AppBrandLogo(size: 40, showShadow: false),
                    const SizedBox(height: AppSpacing.md),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        _statusLabel(booking),
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: statusColor,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      booking.assignedSlot != null && booking.assignedSlot! > 0
                          ? 'Slot ${booking.assignedSlot}'
                          : 'Slot pending',
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: theme.colorScheme.primary,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      booking.shortDisplayParkingName,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      booking.vehicleNumber,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      _statusHint(booking),
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    if (booking.showEntryQrCountdown) ...[
                      const SizedBox(height: AppSpacing.md),
                      ValueListenableBuilder<DateTime>(
                        valueListenable: _now,
                        builder: (_, now, __) {
                          final expired = booking.isEntryQrExpired;
                          final label = expired
                              ? 'Entry QR expired — book a new slot'
                              : '⏱ Entry QR valid for ${booking.entryQrCountdownLabel(now)} (2 hrs max)';
                          final bg = expired
                              ? theme.colorScheme.errorContainer
                              : const Color(0xFFFFF7ED);
                          final fg = expired
                              ? theme.colorScheme.onErrorContainer
                              : const Color(0xFFC2410C);
                          final border = expired
                              ? theme.colorScheme.error
                              : const Color(0xFFFB923C);
                          return Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: bg,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: border, width: 1.5),
                            ),
                            child: Text(
                              label,
                              textAlign: TextAlign.center,
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: fg,
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                    if (booking.isParked) ...[
                      const SizedBox(height: 8),
                      ValueListenableBuilder<DateTime>(
                        valueListenable: _now,
                        builder: (_, __, ___) => Text(
                          booking.elapsedClock(),
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                    if (booking.isQrLive) ...[
                      const SizedBox(height: AppSpacing.lg),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: theme.colorScheme.outlineVariant,
                          ),
                        ),
                        child: QrImageView(
                          data: booking.displayQr,
                          size: 220,
                          backgroundColor: Colors.white,
                        ),
                      ),
                    ] else if (booking.status == BookingStatus.confirmed &&
                        booking.checkedInAt == null) ...[
                      const SizedBox(height: AppSpacing.lg),
                      Text(
                        'This QR is no longer valid. Please book a new slot.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.error,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      FilledButton.icon(
                        onPressed: () => context.go(RoutePaths.vehicleOwnerSearch),
                        icon: const Icon(Icons.local_parking),
                        label: const Text('Book a new slot'),
                      ),
                    ],
                  ],
                ),
              ),
              if (booking.isAwaitingPayment) ...[
                const SizedBox(height: AppSpacing.lg),
                Text(
                  '₹${booking.amountDue!.toStringAsFixed(0)}',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.displaySmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                Text(
                  booking.billedDurationLabel,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                FilledButton.icon(
                  onPressed: () => context.push(
                    RoutePaths.vehicleOwnerPayBooking(booking.id),
                  ),
                  icon: const Icon(Icons.payment),
                  label: Text('Pay ₹${booking.amountDue!.toStringAsFixed(0)}'),
                ),
              ] else if (booking.status == BookingStatus.completed) ...[
                const SizedBox(height: AppSpacing.lg),
                FilledButton.icon(
                  onPressed: () => context.push(
                    RoutePaths.vehicleOwnerBookingReceipt(booking.id),
                  ),
                  icon: const Icon(Icons.receipt_long),
                  label: const Text('View receipt'),
                ),
              ] else ...[
                const SizedBox(height: AppSpacing.md),
                OutlinedButton.icon(
                  onPressed: () =>
                      ref.invalidate(bookingDetailProvider(widget.bookingId)),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Refresh'),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _ParkingPassCard extends StatelessWidget {
  const _ParkingPassCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isLight = theme.brightness == Brightness.light;

    return CustomPaint(
      painter: _DashedBorderPainter(
        color: theme.colorScheme.outlineVariant,
        radius: 20,
      ),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: isLight ? Colors.white : theme.colorScheme.surfaceContainer,
          borderRadius: BorderRadius.circular(20),
          boxShadow: isLight
              ? [
                  BoxShadow(
                    color: AppColors.brandBlue.withValues(alpha: 0.06),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ]
              : null,
        ),
        child: child,
      ),
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  _DashedBorderPainter({required this.color, required this.radius});

  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(1, 1, size.width - 2, size.height - 2),
          Radius.circular(radius),
        ),
      );

    const dashWidth = 6.0;
    const dashSpace = 4.0;
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final end = distance + dashWidth;
        canvas.drawPath(
          metric.extractPath(distance, end.clamp(0, metric.length)),
          paint,
        );
        distance += dashWidth + dashSpace;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter oldDelegate) =>
      oldDelegate.color != color;
}
