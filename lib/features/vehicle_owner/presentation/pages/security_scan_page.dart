import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import 'package:open_space_parking/core/common/exceptions/app_exception.dart';
import 'package:open_space_parking/core/di/service_locator.dart';
import 'package:open_space_parking/core/providers/core_providers.dart';
import 'package:open_space_parking/core/routes/route_paths.dart';
import 'package:open_space_parking/core/theme/app_colors.dart';
import 'package:open_space_parking/core/utils/camera_access.dart';
import 'package:open_space_parking/core/widgets/dialogs/app_dialogs.dart';
import 'package:open_space_parking/features/account/presentation/pages/role_account_pages.dart';
import 'package:open_space_parking/features/authentication/presentation/providers/auth_form_providers.dart';
import 'package:open_space_parking/features/authentication/presentation/providers/auth_state_provider.dart';
import 'package:open_space_parking/features/vehicle_owner/domain/entities/booking.dart';
import 'package:open_space_parking/features/vehicle_owner/domain/repositories/vehicle_owner_repository.dart';

enum _SecurityView { desk, scanner }

/// Gate desk: stay signed in; open scanner only when needed; back returns to desk.
class SecurityScanPage extends ConsumerStatefulWidget {
  const SecurityScanPage({super.key});

  @override
  ConsumerState<SecurityScanPage> createState() => _SecurityScanPageState();
}

class _SecurityScanPageState extends ConsumerState<SecurityScanPage> {
  late MobileScannerController _scannerController;
  _SecurityView _view = _SecurityView.desk;
  bool _scanning = false;
  bool _cameraPaused = true;
  Booking? _result;
  String? _action;

  @override
  void initState() {
    super.initState();
    _scannerController = _createController();
  }

  MobileScannerController _createController() {
    return MobileScannerController(
      detectionSpeed: DetectionSpeed.noDuplicates,
      facing: CameraFacing.back,
      formats: const [BarcodeFormat.qrCode],
      autoStart: false,
    );
  }

  @override
  void dispose() {
    _scannerController.dispose();
    super.dispose();
  }

  Future<bool> _ensureCameraReady() async {
    final permission = await CameraAccess.ensure(
      context: context,
      purpose: 'scan parking QR codes',
    );
    if (permission == CameraPermissionStatus.granted) return true;
    if (!mounted) return false;
    ref.read(snackbarServiceProvider).showError(
          CameraAccess.messageFor(
            permission,
            purpose: 'scan parking QR codes',
          ),
        );
    return false;
  }

  Future<void> _openScanner() async {
    if (!await _ensureCameraReady()) return;

    setState(() {
      _view = _SecurityView.scanner;
      _result = null;
      _action = null;
      _cameraPaused = false;
      _scanning = false;
    });
    try {
      await _scannerController.start();
    } catch (_) {
      if (mounted) {
        ref.read(snackbarServiceProvider).showError(
              'Camera could not start. Check camera permission and try again.',
            );
        setState(() => _cameraPaused = true);
      }
    }
  }

  Future<void> _returnToDesk() async {
    unawaited(_stopScannerQuietly());
    if (!mounted) return;
    setState(() {
      _view = _SecurityView.desk;
      _cameraPaused = true;
      _scanning = false;
      _result = null;
      _action = null;
    });
  }

  Future<void> _processCode(String raw) async {
    final code = raw.trim();
    if (code.isEmpty || _scanning) return;

    setState(() {
      _scanning = true;
      _result = null;
      _action = null;
    });
    try {
      final before = await sl<VehicleOwnerRepository>().getBookingByQr(code);
      final booking = await sl<VehicleOwnerRepository>().scanParkingQr(code);

      String action;
      if (before?.checkedInAt == null && booking.checkedInAt != null) {
        action = 'started';
        ref.read(snackbarServiceProvider).showSuccess(
              'Session started for slot ${booking.assignedSlot ?? '-'}.',
            );
      } else if (booking.isAwaitingPayment) {
        action = 'stopped';
        ref.read(snackbarServiceProvider).showSuccess(
              'Session stopped. Bill is on the driver phone.',
            );
      } else {
        action = 'updated';
        ref.read(snackbarServiceProvider).showSuccess('QR processed.');
      }

      setState(() {
        _result = booking;
        _action = action;
      });
      await _pauseCamera();
    } on AppException catch (e) {
      final msg = e.message.toLowerCase();
      if (msg.contains('authentication') ||
          msg.contains('session expired') ||
          msg.contains('invalid or expired token')) {
        ref.read(snackbarServiceProvider).showError(
              'Gate session expired. Sign out and sign in again, then scan.',
            );
      } else if (msg.contains('not found')) {
        ref.read(snackbarServiceProvider).showError(
              'Booking not found. Ask the driver to open their parking ticket QR.',
            );
      } else {
        ref.read(snackbarServiceProvider).showError(e.message);
      }
    } catch (_) {
      ref.read(snackbarServiceProvider).showError(
            'Scan failed. Check internet connection and try again.',
          );
    } finally {
      if (mounted) setState(() => _scanning = false);
    }
  }

  Future<void> _pauseCamera() async {
    try {
      await _scannerController.stop();
    } catch (_) {}
    if (mounted) setState(() => _cameraPaused = true);
  }

  Future<void> _resumeCamera() async {
    if (!await _ensureCameraReady()) return;

    setState(() {
      _result = null;
      _action = null;
      _cameraPaused = false;
    });
    try {
      await _scannerController.start();
    } catch (_) {
      if (mounted) {
        ref.read(snackbarServiceProvider).showError(
              'Camera could not start. Check camera permission and try again.',
            );
        setState(() => _cameraPaused = true);
      }
    }
  }

  Future<void> _retryCamera() async {
    if (!await _ensureCameraReady()) return;

    await _scannerController.dispose();
    setState(() {
      _scannerController = _createController();
      _cameraPaused = false;
      _result = null;
      _action = null;
    });
    try {
      await _scannerController.start();
    } catch (_) {
      if (mounted) setState(() => _cameraPaused = true);
    }
  }

  void _onDetect(BarcodeCapture capture) {
    if (_scanning || _cameraPaused || _view != _SecurityView.scanner) return;
    for (final barcode in capture.barcodes) {
      final value = barcode.rawValue;
      if (value != null && value.trim().isNotEmpty) {
        _processCode(value);
        return;
      }
    }
  }

  Future<void> _stopScannerQuietly() async {
    try {
      await _scannerController.stop().timeout(const Duration(seconds: 1));
    } catch (_) {}
  }

  Future<void> _logout() async {
    final confirmed = await AppDialogs.confirmLogout(context);
    if (!confirmed || !mounted) return;

    if (_view == _SecurityView.scanner) {
      setState(() {
        _view = _SecurityView.desk;
        _cameraPaused = true;
        _scanning = false;
      });
    }
    // Never block sign-out on camera teardown (common hang on web).
    unawaited(_stopScannerQuietly());

    ref.read(phoneAuthStepProvider.notifier).state = PhoneAuthStep.enterPhone;
    ref.read(verifiedPhoneProvider.notifier).state = null;
    ref.read(authLoadingProvider.notifier).state = false;

    await ref.read(authStateProvider.notifier).logout();
    if (!mounted) return;
    context.go(RoutePaths.authEntry);
  }

  Future<void> _onSystemBack() async {
    if (_view == _SecurityView.scanner) {
      await _returnToDesk();
      return;
    }
    await _logout();
  }

  @override
  Widget build(BuildContext context) {
    final result = _result;
    final name = ref.watch(authStateProvider).session?.displayName ?? 'Security';
    final colorScheme = Theme.of(context).colorScheme;
    final onScanner = _view == _SecurityView.scanner;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        await _onSystemBack();
      },
      child: Scaffold(
        backgroundColor: onScanner ? Colors.black : colorScheme.surface,
        appBar: AppBar(
          title: Text(onScanner ? 'Scan parking QR' : 'Security'),
          backgroundColor: onScanner ? Colors.black : colorScheme.surfaceContainer,
          foregroundColor: onScanner ? Colors.white : colorScheme.onSurface,
          surfaceTintColor: Colors.transparent,
          leading: onScanner
              ? IconButton(
                  tooltip: 'Back to gate desk',
                  onPressed: _returnToDesk,
                  icon: const Icon(Icons.arrow_back),
                )
              : null,
          actions: [
            if (!onScanner)
              IconButton(
                tooltip: 'My Account',
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const SecurityProfilePage(),
                    ),
                  );
                },
                icon: const Icon(Icons.person_outline),
              ),
            if (onScanner)
              IconButton(
                tooltip: 'Sign out',
                onPressed: _logout,
                icon: const Icon(Icons.logout),
              ),
          ],
        ),
        body: onScanner
            ? _buildScannerBody(context, name, result)
            : _buildDeskBody(context, name),
      ),
    );
  }

  Widget _buildDeskBody(BuildContext context, String name) {
    final colorScheme = Theme.of(context).colorScheme;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Spacer(),
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: AppColors.brandBlueSoft,
                borderRadius: BorderRadius.circular(20),
              ),
              alignment: Alignment.center,
              child: const Icon(
                Icons.qr_code_scanner,
                size: 44,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'SECURITY',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    letterSpacing: 2,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Signed in as $name',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Scan a driver QR to start or stop a parking session.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
            ),
            const Spacer(),
            FilledButton.icon(
              onPressed: _openScanner,
              icon: const Icon(Icons.qr_code_scanner),
              label: const Text('Scan parking QR'),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const SecurityProfilePage(),
                  ),
                );
              },
              icon: const Icon(Icons.person_outline),
              label: const Text('My Account'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScannerBody(
    BuildContext context,
    String name,
    Booking? result,
  ) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Text(
            'Gate desk — $name\nPoint the camera at the driver QR. '
            'First scan starts the session. Same QR again stops and bills.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.white,
                ),
            textAlign: TextAlign.center,
          ),
        ),
        Expanded(
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (_cameraPaused)
                ColoredBox(
                  color: Colors.black,
                  child: Center(
                    child: result == null
                        ? TextButton.icon(
                            onPressed: _resumeCamera,
                            icon: const Icon(Icons.qr_code_scanner),
                            label: const Text('Scan next vehicle'),
                          )
                        : const SizedBox.shrink(),
                  ),
                )
              else
                MobileScanner(
                  key: ObjectKey(_scannerController),
                  controller: _scannerController,
                  onDetect: _onDetect,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, _) {
                    final permissionDenied = error.errorCode ==
                        MobileScannerErrorCode.permissionDenied;
                    return ColoredBox(
                      color: Colors.black,
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.photo_camera_outlined,
                              color: Colors.white,
                              size: 56,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              permissionDenied
                                  ? 'Allow camera access to scan the parking QR.'
                                  : 'Camera could not start. Check camera permission and try again.',
                              style: const TextStyle(color: Colors.white),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 20),
                            FilledButton.icon(
                              onPressed: _retryCamera,
                              icon: const Icon(Icons.camera_alt),
                              label: const Text('Open camera'),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                  overlayBuilder: (context, constraints) {
                    final size = constraints.biggest.shortestSide * 0.7;
                    return Center(
                      child: Container(
                        width: size,
                        height: size,
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.white, width: 3),
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                    );
                  },
                ),
              if (_scanning)
                const ColoredBox(
                  color: Color(0x66000000),
                  child: Center(child: CircularProgressIndicator()),
                ),
              if (result != null)
                Align(
                  alignment: Alignment.bottomCenter,
                  child: _ScanResultCard(
                    booking: result,
                    action: _action,
                    onScanNext: _resumeCamera,
                    onBackToDesk: _returnToDesk,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ScanResultCard extends StatelessWidget {
  const _ScanResultCard({
    required this.booking,
    required this.action,
    required this.onScanNext,
    required this.onBackToDesk,
  });

  final Booking booking;
  final String? action;
  final VoidCallback onScanNext;
  final VoidCallback onBackToDesk;

  @override
  Widget build(BuildContext context) {
    final timeFormat = DateFormat('dd MMM yyyy, hh:mm a');
    final title = action == 'started'
        ? 'Entry — session started'
        : action == 'stopped'
            ? 'Exit — session stopped'
            : 'Scan result';

    return Material(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            _row('Parking', booking.displayParkingName),
            _row('Slot no', '${booking.assignedSlot ?? '-'}'),
            _row('Session ID', booking.displaySessionId),
            _row('Vehicle', booking.vehicleNumber),
            if (booking.checkedInAt != null)
              _row('Start time', timeFormat.format(booking.checkedInAt!.toLocal())),
            if (booking.isParked) _row('Status', 'Timer running'),
            if (booking.isAwaitingPayment) ...[
              if (booking.checkedOutAt != null)
                _row(
                  'Stop time',
                  timeFormat.format(booking.checkedOutAt!.toLocal()),
                ),
              _row('Duration', booking.billedDurationLabel),
              _row(
                'Amount due',
                '₹${(booking.amountDue ?? booking.totalPrice).toStringAsFixed(0)}',
              ),
              const SizedBox(height: 8),
              Text(
                'Ask the driver to tap Pay with Razorpay on their ticket.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: onScanNext,
                icon: const Icon(Icons.qr_code_scanner),
                label: const Text('Scan next vehicle'),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: onBackToDesk,
                child: const Text('Back to gate desk'),
              ),
            ),
          ],
        ),
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
