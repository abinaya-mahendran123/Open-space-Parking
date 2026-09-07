import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:open_space_parking/core/providers/core_providers.dart';
import 'package:open_space_parking/core/common/exceptions/app_exception.dart';
import 'package:open_space_parking/core/routes/route_paths.dart';
import 'package:open_space_parking/core/theme/app_spacing.dart';
import 'package:open_space_parking/core/widgets/errors/app_error_widget.dart';
import 'package:open_space_parking/core/widgets/loading/app_loading_widget.dart';
import 'package:open_space_parking/features/authentication/presentation/providers/auth_state_provider.dart';
import 'package:open_space_parking/features/vehicle_owner/domain/entities/booking.dart';
import 'package:open_space_parking/features/vehicle_owner/presentation/providers/vehicle_owner_providers.dart';
import 'package:open_space_parking/features/vehicle_owner/presentation/widgets/booking_card.dart';
import 'package:open_space_parking/features/vehicle_owner/presentation/widgets/vehicle_owner_app_bar_actions.dart';
import 'package:open_space_parking/features/vehicle_owner/presentation/widgets/vehicle_owner_empty_state.dart';

class MyBookingsPage extends ConsumerStatefulWidget {
  const MyBookingsPage({super.key});

  @override
  ConsumerState<MyBookingsPage> createState() => _MyBookingsPageState();
}

class _MyBookingsPageState extends ConsumerState<MyBookingsPage> {
  bool _selecting = false;
  final Set<String> _selectedIds = <String>{};

  void _openTicket(BuildContext context, Booking booking) {
    context.push(RoutePaths.vehicleOwnerParkingTicket(booking.id));
  }

  void _openDetail(BuildContext context, Booking booking) {
    context.push(RoutePaths.vehicleOwnerBookingDetail(booking.id));
  }

  void _enterSelectMode([String? initialId]) {
    setState(() {
      _selecting = true;
      _selectedIds.clear();
      if (initialId != null) _selectedIds.add(initialId);
    });
  }

  void _exitSelectMode() {
    setState(() {
      _selecting = false;
      _selectedIds.clear();
    });
  }

  void _toggleSelected(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
    });
  }

  void _selectAll(List<Booking> deletable) {
    setState(() {
      _selectedIds
        ..clear()
        ..addAll(deletable.map((b) => b.id));
    });
  }

  Future<void> _deleteIds(String vehicleOwnerId, List<String> ids) async {
    if (ids.isEmpty) return;
    final count = ids.length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete $count histor${count == 1 ? 'y item' : 'y items'}?'),
        content: const Text(
          'Selected bookings will be removed from your History. '
          'Active parking sessions cannot be deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await ref.read(vehicleOwnerRepositoryProvider).hideBookingsFromHistory(
            vehicleOwnerId: vehicleOwnerId,
            bookingIds: ids,
          );
      _exitSelectMode();
      ref.invalidate(vehicleOwnerBookingsProvider(vehicleOwnerId));
      if (!mounted) return;
      ref.read(snackbarServiceProvider).showSuccess(
            '$count item${count == 1 ? '' : 's'} deleted from history.',
          );
    } catch (e) {
      ref.invalidate(vehicleOwnerBookingsProvider(vehicleOwnerId));
      if (!mounted) return;
      final message = e is AppException
          ? e.message
          : 'Could not delete history items.';
      ref.read(snackbarServiceProvider).showError(message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final vehicleOwnerId = ref.watch(authStateProvider).session?.userId ?? '';
    final bookingsAsync =
        ref.watch(vehicleOwnerBookingsProvider(vehicleOwnerId));

    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: Text(_selecting ? 'Select history' : 'History'),
        backgroundColor: colorScheme.surfaceContainer,
        surfaceTintColor: Colors.transparent,
        leading: _selecting
            ? IconButton(
                tooltip: 'Cancel',
                onPressed: _exitSelectMode,
                icon: const Icon(Icons.close),
              )
            : null,
        actions: [
          if (_selecting)
            IconButton(
              tooltip: 'Delete selected',
              onPressed: _selectedIds.isEmpty
                  ? null
                  : () => _deleteIds(vehicleOwnerId, _selectedIds.toList()),
              icon: const Icon(Icons.delete_outline),
            )
          else
            const VehicleOwnerAppBarActions(),
        ],
      ),
      body: bookingsAsync.when(
        loading: () => const AppLoadingWidget(message: 'Loading bookings...'),
        error: (_, __) => AppErrorWidget(
          message: 'Failed to load bookings',
          onRetry: () =>
              ref.invalidate(vehicleOwnerBookingsProvider(vehicleOwnerId)),
        ),
        data: (bookings) {
          if (bookings.isEmpty) {
            return VehicleOwnerEmptyState(
              icon: Icons.history,
              title: 'No bookings yet',
              message: 'Find a parking space near you.',
              actionLabel: 'Find parking',
              onAction: () => context.go(RoutePaths.vehicleOwnerSearch),
            );
          }

          final live = bookings.where((b) => b.isQrLive).toList();
          final past = bookings.where((b) => !b.isQrLive).toList();
          final rows = <Object>[
            if (live.isNotEmpty) ...['Active', ...live],
            if (past.isNotEmpty) ...['Past', ...past],
          ];
          final selectedCount = _selectedIds.length;

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  AppSpacing.sm,
                  AppSpacing.md,
                  0,
                ),
                child: _selecting
                    ? Row(
                        children: [
                          TextButton(
                            onPressed: _exitSelectMode,
                            child: const Text('Cancel'),
                          ),
                          TextButton(
                            onPressed: past.isEmpty
                                ? null
                                : () => _selectAll(past),
                            child: const Text('Select all'),
                          ),
                          const Spacer(),
                          FilledButton.tonalIcon(
                            onPressed: selectedCount == 0
                                ? null
                                : () => _deleteIds(
                                      vehicleOwnerId,
                                      _selectedIds.toList(),
                                    ),
                            icon: const Icon(Icons.delete_outline),
                            label: Text('Delete ($selectedCount)'),
                          ),
                        ],
                      )
                    : Row(
                        children: [
                          const Spacer(),
                          if (past.isNotEmpty) ...[
                            TextButton.icon(
                              onPressed: _enterSelectMode,
                              icon: const Icon(Icons.checklist),
                              label: const Text('Select'),
                            ),
                            TextButton.icon(
                              onPressed: () => _deleteIds(
                                vehicleOwnerId,
                                past.map((b) => b.id).toList(),
                              ),
                              icon: const Icon(Icons.delete_outline),
                              label: const Text('Clear all'),
                            ),
                          ],
                        ],
                      ),
              ),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () async => ref
                      .invalidate(vehicleOwnerBookingsProvider(vehicleOwnerId)),
                  child: ListView.builder(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    itemCount: rows.length,
                    itemBuilder: (context, index) {
                      final row = rows[index];
                      if (row is String) {
                        return Padding(
                          padding: EdgeInsets.only(
                            top: index == 0 ? 0 : AppSpacing.md,
                            bottom: AppSpacing.sm,
                          ),
                          child: Text(
                            row,
                            style: Theme.of(context)
                                .textTheme
                                .titleSmall
                                ?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: row == 'Active'
                                      ? Theme.of(context).colorScheme.primary
                                      : null,
                                ),
                          ),
                        );
                      }
                      final booking = row as Booking;
                      final isLive = booking.isQrLive;
                      final canSelect = !isLive;
                      return BookingCard(
                        booking: booking,
                        selecting: _selecting && canSelect,
                        selected: _selectedIds.contains(booking.id),
                        onSelectedChanged: canSelect
                            ? (selected) {
                                if (!_selecting) {
                                  _enterSelectMode(
                                    selected ? booking.id : null,
                                  );
                                  return;
                                }
                                setState(() {
                                  if (selected) {
                                    _selectedIds.add(booking.id);
                                  } else {
                                    _selectedIds.remove(booking.id);
                                  }
                                });
                              }
                            : null,
                        onTap: () {
                          if (_selecting) {
                            if (canSelect) _toggleSelected(booking.id);
                            return;
                          }
                          if (isLive) {
                            _openTicket(context, booking);
                          } else {
                            _openDetail(context, booking);
                          }
                        },
                        onShowQr: isLive && !_selecting
                            ? () => _openTicket(context, booking)
                            : null,
                      );
                    },
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
