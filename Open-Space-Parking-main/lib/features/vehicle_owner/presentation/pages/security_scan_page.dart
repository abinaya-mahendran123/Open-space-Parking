import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:open_space_parking/core/common/exceptions/app_exception.dart';
import 'package:open_space_parking/core/di/service_locator.dart';
import 'package:open_space_parking/core/providers/core_providers.dart';
import 'package:open_space_parking/core/widgets/buttons/primary_button.dart';
import 'package:open_space_parking/core/widgets/textfields/app_text_field.dart';
import 'package:open_space_parking/features/vehicle_owner/domain/entities/booking.dart';
import 'package:open_space_parking/features/vehicle_owner/domain/repositories/vehicle_owner_repository.dart';

/// Gate desk: enter / scan QR payload → bill actual duration.
class SecurityScanPage extends ConsumerStatefulWidget {
  const SecurityScanPage({super.key});

  @override
  ConsumerState<SecurityScanPage> createState() => _SecurityScanPageState();
}

class _SecurityScanPageState extends ConsumerState<SecurityScanPage> {
  final _qrController = TextEditingController();
  bool _scanning = false;
  Booking? _result;

  @override
  void dispose() {
    _qrController.dispose();
    super.dispose();
  }

  Future<void> _scan() async {
    setState(() {
      _scanning = true;
      _result = null;
    });
    try {
      final booking = await sl<VehicleOwnerRepository>()
          .scanQrForCheckout(_qrController.text);
      setState(() => _result = booking);
      ref.read(snackbarServiceProvider).showSuccess(
            'Duration calculated. Ask driver to pay in the app.',
          );
    } on AppException catch (e) {
      ref.read(snackbarServiceProvider).showError(e.message);
    } catch (_) {
      ref.read(snackbarServiceProvider).showError('Scan failed.');
    } finally {
      if (mounted) setState(() => _scanning = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final result = _result;

    return Scaffold(
      appBar: AppBar(title: const Text('Security QR Scan')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Scan desk',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          const Text(
            'Enter the booking QR code shown on the driver’s ticket '
            '(camera scan can be added on mobile). This calculates actual '
            'parking duration and amount due.',
          ),
          const SizedBox(height: 24),
          AppTextField(
            controller: _qrController,
            label: 'QR / Booking reference',
          ),
          const SizedBox(height: 16),
          PrimaryButton(
            label: _scanning ? 'Scanning...' : 'Scan & Calculate',
            onPressed: _scanning ? null : _scan,
          ),
          if (result != null) ...[
            const SizedBox(height: 24),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Checkout bill',
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 12),
                    _row('Vehicle', result.vehicleNumber),
                    _row('Slot', '${result.assignedSlot ?? '-'}'),
                    _row('Ref', result.bookingRef),
                    _row(
                      'Duration',
                      '${(result.actualDurationHours ?? result.durationHours).toStringAsFixed(2)} hrs',
                    ),
                    _row(
                      'Amount due',
                      '₹${(result.amountDue ?? result.totalPrice).toStringAsFixed(0)}',
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Driver must pay in the app to release the slot.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          SizedBox(width: 110, child: Text(label)),
          Expanded(
            child: Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}
