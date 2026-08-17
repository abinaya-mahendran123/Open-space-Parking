import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:open_space_parking/core/common/exceptions/app_exception.dart';
import 'package:open_space_parking/core/config/environment_config.dart';
import 'package:open_space_parking/core/services/api/ticket_sms_delivery_result.dart';
import 'package:open_space_parking/core/utils/phone_utils.dart';

class TicketNotificationService {
  TicketNotificationService({http.Client? httpClient})
      : _httpClient = httpClient ?? http.Client();

  final http.Client _httpClient;

  Future<TicketSmsDeliveryResult> sendTicketAssignment({
    required String employeePhone,
    required String employeeName,
    required String ticketId,
    required String ownerName,
    required String ownerPhone,
    required String location,
    required String requestType,
  }) async {
    final normalizedPhone = PhoneUtils.normalizeIndianMobile(employeePhone);
    if (normalizedPhone.isEmpty) {
      throw const AppException('Employee mobile number is required.');
    }

    final uri = Uri.parse(
      '${EnvironmentConfig.baseApiUrl}/api/notifications/ticket-assignment',
    );

    http.Response response;
    try {
      response = await _httpClient.post(
        uri,
        headers: const {'Content-Type': 'application/json'},
        body: jsonEncode({
          'phone': normalizedPhone,
          'employeeName': employeeName,
          'ticketId': ticketId,
          'ownerName': ownerName,
          'ownerPhone': PhoneUtils.normalizeIndianMobile(ownerPhone),
          'location': location,
          'requestType': requestType,
        }),
      );
    } on http.ClientException {
      throw AppException(
        'Could not reach the notification server at ${EnvironmentConfig.baseApiUrl}. '
        'Start it with: cd backend && npm start',
      );
    } catch (e) {
      throw AppException('Could not send ticket SMS: $e');
    }

    Map<String, dynamic> body;
    try {
      body = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      throw const AppException(
        'Invalid response from notification server. Is the backend running?',
      );
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw AppException(
        body['error']?.toString() ??
            'Could not send ticket SMS to the employee.',
      );
    }

    if (body['ok'] != true) {
      throw const AppException('Ticket SMS was not accepted by the server.');
    }

    final simulated = body['simulated'] == true;
    if (simulated) {
      throw const AppException(
        'SMS is not configured on the server. Set TWILIO_ACCOUNT_SID, '
        'TWILIO_AUTH_TOKEN, and TWILIO_SMS_FROM in the backend environment.',
      );
    }

    return TicketSmsDeliveryResult(
      delivered: true,
      phone: body['phone']?.toString() ?? normalizedPhone,
      messageId: body['messageId']?.toString(),
    );
  }
}
