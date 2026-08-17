import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:open_space_parking/core/config/environment_config.dart';
import 'package:open_space_parking/core/utils/app_logger.dart';
import 'package:open_space_parking/core/whatsapp/data/providers/whatsapp_api_client.dart';
import 'package:open_space_parking/core/whatsapp/domain/entities/whatsapp_message.dart';
import 'package:open_space_parking/core/whatsapp/domain/entities/whatsapp_provider_type.dart';

/// Placeholder client for Meta WhatsApp Business Cloud API.
///
/// Docs: https://developers.facebook.com/docs/whatsapp/cloud-api
class MetaWhatsAppClient extends WhatsAppApiClient {
  MetaWhatsAppClient()
      : super(
          isConfigured: EnvironmentConfig.isMetaWhatsAppConfigured,
        );

  static const String _graphBaseUrl = 'https://graph.facebook.com/v21.0';

  @override
  Future<WhatsAppSendResult> sendMessage(WhatsAppMessage message) async {
    if (!isConfigured) {
      AppLogger.i(
        '[Meta WhatsApp placeholder] To: ${message.toPhone} | ${message.body}',
      );
      return WhatsAppSendResult.simulated(
        provider: WhatsAppProviderType.meta,
      );
    }

    final uri = Uri.parse(
      '$_graphBaseUrl/${EnvironmentConfig.metaWhatsAppPhoneNumberId}/messages',
    );

    final payload = {
      'messaging_product': 'whatsapp',
      'to': _normalizePhone(message.toPhone),
      'type': 'text',
      'text': {'body': message.body},
    };

    try {
      final response = await http.post(
        uri,
        headers: {
          'Authorization': 'Bearer ${EnvironmentConfig.metaWhatsAppAccessToken}',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(payload),
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        final messages = json['messages'] as List<dynamic>?;
        final messageId = messages?.isNotEmpty == true
            ? messages!.first['id'] as String?
            : null;
        return WhatsAppSendResult(
          success: true,
          provider: WhatsAppProviderType.meta,
          messageId: messageId,
        );
      }

      return WhatsAppSendResult.failure(
        provider: WhatsAppProviderType.meta,
        errorMessage: response.body,
      );
    } catch (e) {
      return WhatsAppSendResult.failure(
        provider: WhatsAppProviderType.meta,
        errorMessage: e.toString(),
      );
    }
  }

  String _normalizePhone(String phone) {
    return phone.replaceAll(RegExp(r'[^\d+]'), '');
  }
}
