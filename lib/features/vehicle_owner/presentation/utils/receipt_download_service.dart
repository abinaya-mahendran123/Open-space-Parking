import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:permission_handler/permission_handler.dart';

import 'package:open_space_parking/features/vehicle_owner/domain/entities/booking.dart';
import 'package:open_space_parking/features/vehicle_owner/domain/entities/parking_payment_split.dart';

class ReceiptDownloadService {
  ReceiptDownloadService._();

  static const _downloadsChannel = MethodChannel('open_space_parking/downloads');
  static final _dateFormat = DateFormat('dd MMM yyyy, hh:mm a');
  static const _brandBlue = PdfColor.fromInt(0xFF2B65EC);

  static Future<Uint8List> buildReceiptPdf(Booking booking) async {
    final paid = booking.paidAmount ?? booking.totalPrice;
    final duration = booking.actualDurationHours ?? booking.durationHours;
    final doc = pw.Document();

    pw.Widget row(String label, String value, {bool bold = false}) {
      return pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 5),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.SizedBox(
              width: 130,
              child: pw.Text(
                label,
                style: pw.TextStyle(
                  fontSize: 11,
                  color: PdfColors.grey700,
                ),
              ),
            ),
            pw.Expanded(
              child: pw.Text(
                value,
                style: pw.TextStyle(
                  fontSize: 11,
                  fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
                ),
              ),
            ),
          ],
        ),
      );
    }

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              pw.Container(
                padding: const pw.EdgeInsets.all(16),
                decoration: pw.BoxDecoration(
                  color: _brandBlue,
                  borderRadius: pw.BorderRadius.circular(10),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'OPEN SPACE PARKING',
                      style: pw.TextStyle(
                        color: PdfColors.white,
                        fontSize: 18,
                        fontWeight: pw.FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      'Payment Receipt',
                      style: const pw.TextStyle(
                        color: PdfColors.white,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 24),
              pw.Text(
                'Booking details',
                style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 8),
              pw.Container(
                padding: const pw.EdgeInsets.all(14),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey300),
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                child: pw.Column(
                  children: [
                    row('Session ID', booking.displaySessionId),
                    row('Parking', booking.displayParkingName),
                    row('Vehicle', booking.vehicleNumber),
                    row('Slot', '${booking.assignedSlot ?? '-'}'),
                    if (booking.checkedInAt != null)
                      row(
                        'Check-in',
                        _dateFormat.format(booking.checkedInAt!.toLocal()),
                      ),
                    if (booking.checkedOutAt != null)
                      row(
                        'Check-out',
                        _dateFormat.format(booking.checkedOutAt!.toLocal()),
                      ),
                    row('Duration', '${duration.toStringAsFixed(2)} hrs'),
                  ],
                ),
              ),
              pw.SizedBox(height: 16),
              pw.Text(
                'Payment',
                style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 8),
              pw.Container(
                padding: const pw.EdgeInsets.all(14),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey300),
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                child: pw.Column(
                  children: [
                    row(
                      'Amount paid',
                      'Rs ${paid.toStringAsFixed(0)}',
                      bold: true,
                    ),
                    row(
                      'Platform (10%)',
                      'Rs ${ParkingPaymentSplit.platformAmount(paid).toStringAsFixed(0)}',
                    ),
                    row(
                      'Land owner (90%)',
                      'Rs ${ParkingPaymentSplit.landOwnerAmount(paid).toStringAsFixed(0)}',
                    ),
                    if (booking.paidAt != null)
                      row(
                        'Paid at',
                        _dateFormat.format(booking.paidAt!.toLocal()),
                      ),
                    if (booking.paymentId != null &&
                        booking.paymentId!.trim().isNotEmpty)
                      row('Payment ID', booking.paymentId!),
                  ],
                ),
              ),
              pw.Spacer(),
              pw.Divider(color: PdfColors.grey300),
              pw.SizedBox(height: 8),
              pw.Text(
                'Thank you for parking with Open Space Parking.',
                textAlign: pw.TextAlign.center,
                style: const pw.TextStyle(
                  fontSize: 10,
                  color: PdfColors.grey600,
                ),
              ),
            ],
          );
        },
      ),
    );

    return doc.save();
  }

  /// Saves the receipt PDF without a share/save picker.
  /// Android → public Downloads. iPhone → Files app (On My iPhone → app).
  /// Returns a short success message for the snackbar.
  static Future<String> downloadReceipt(Booking booking) async {
    final bytes = await buildReceiptPdf(booking);
    final safeId = booking.displaySessionId.replaceAll(RegExp(r'[^\w-]'), '_');
    final fileName = 'open_space_receipt_$safeId.pdf';

    if (Platform.isAndroid) {
      // Needed only on older Android; no-op / auto-granted on Android 10+.
      await Permission.storage.request();

      await _downloadsChannel.invokeMethod<String>(
        'saveToDownloads',
        <String, dynamic>{
          'fileName': fileName,
          'bytes': bytes,
          'mimeType': 'application/pdf',
        },
      );
      return 'Receipt saved to Downloads';
    }

    if (Platform.isIOS) {
      // iOS has no public Downloads folder. Save into app Documents so it
      // appears in Files → On My iPhone → Open Space Parking (file sharing on).
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/$fileName');
      await file.writeAsBytes(bytes, flush: true);
      return 'Receipt saved — open Files → On My iPhone → Open Space Parking';
    }

    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/$fileName');
    await file.writeAsBytes(bytes, flush: true);
    return 'Receipt saved';
  }

  /// Kept for callers that still use the old name.
  static Future<String> shareReceipt(Booking booking) => downloadReceipt(booking);
}
