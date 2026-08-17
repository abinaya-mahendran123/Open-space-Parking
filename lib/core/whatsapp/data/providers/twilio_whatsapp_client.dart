import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:open_space_parking/core/config/environment_config.dart';
import 'package:open_space_parking/core/utils/app_logger.dart';
import 'package:open_space_parking/core/whatsapp/data/providers/whatsapp_api_client.dart';
import 'package:open_space_parking/core/whatsapp/domain/entities/whatsapp_message.dart';
import 'package:open_space_parking/core/whatsapp/domain/entities/whatsapp_provider_type.dart';

/// Placeholder client for Twilio WhatsApp API.
///
/// Docs: https://www.twilio.com/docs/whatsapp/api
class TwilioWhatsAppClient extends WhatsAppApiClient {
  TwilioWhatsAppClient()
      : super(
          isConfigured: EnvironmentConfig.isTwilioWhatsAppConfigured,
        );

  @override
  Future<WhatsAppSendResult> sendMessage(WhatsAppMessage message) async {
    if (!isConfigured) {
      AppLogger.i(
        '[Twilio WhatsApp placeholder] To: ${message.toPhone} | ${message.body}',
      );
      return WhatsAppSendResult.simulated(
        provider: WhatsAppProviderType.twilio,
      );
    }

    final accountSid = EnvironmentConfig.twilioAccountSid;
    final uri = Uri.parse(
      'https://api.twilio.com/2010-04-01/Accounts/$accountSid/Messages.json',
    );

    final credentials = base64Encode(
      utf8.encode(
        '${EnvironmentConfig.twilioAccountSid}:${EnvironmentConfig.twilioAuthToken}',
      ),
    );

    try {
      final response = await http.post(
        uri,
        headers: {
          'Authorization': 'Basic $credentials',
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: {
          'From': EnvironmentConfig.twilioWhatsAppFrom,
          'To': _toWhatsAppAddress(message.toPhone),
          'Body': message.body,
        },
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        return WhatsAppSendResult(
          success: true,
          provider: WhatsAppProviderType.twilio,
          messageId: json['sid'] as String?,
        );
      }

      return WhatsAppSendResult.failure(
        provider: WhatsAppProviderType.twilio,
        errorMessage: response.body,
      );
    } catch (e) {
      return WhatsAppSendResult.failure(
        provider: WhatsAppProviderType.twilio,
        errorMessage: e.toString(),
      );
    }
  }

  String _toWhatsAppAddress(String phone) {
    final normalized = phone.replaceAll(RegExp(r'[^\d+]'), '');
    if (normalized.startsWith('whatsapp:')) return normalized;
    return 'whatsapp:$normalized';
  }
}
