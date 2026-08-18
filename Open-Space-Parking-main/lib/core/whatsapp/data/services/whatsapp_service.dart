import 'package:open_space_parking/core/config/environment_config.dart';
import 'package:open_space_parking/core/utils/app_logger.dart';
import 'package:open_space_parking/core/utils/phone_utils.dart';
import 'package:open_space_parking/core/whatsapp/data/providers/meta_whatsapp_client.dart';
import 'package:open_space_parking/core/whatsapp/data/providers/twilio_whatsapp_client.dart';
import 'package:open_space_parking/core/whatsapp/data/providers/whatsapp_api_client.dart';
import 'package:open_space_parking/core/whatsapp/data/templates/whatsapp_templates.dart';
import 'package:open_space_parking/core/whatsapp/domain/entities/whatsapp_message.dart';
import 'package:open_space_parking/core/whatsapp/domain/entities/whatsapp_provider_type.dart';
import 'package:open_space_parking/core/whatsapp/domain/entities/whatsapp_template_id.dart';

class WhatsAppService {
  WhatsAppService({
    MetaWhatsAppClient? metaClient,
    TwilioWhatsAppClient? twilioClient,
  })  : _metaClient = metaClient ?? MetaWhatsAppClient(),
        _twilioClient = twilioClient ?? TwilioWhatsAppClient();

  final MetaWhatsAppClient _metaClient;
  final TwilioWhatsAppClient _twilioClient;

  WhatsAppProviderType get activeProvider =>
      EnvironmentConfig.whatsappProvider;

  WhatsAppApiClient get _client {
    return switch (activeProvider) {
      WhatsAppProviderType.meta => _metaClient,
      WhatsAppProviderType.twilio => _twilioClient,
      WhatsAppProviderType.none => _metaClient,
    };
  }

  Future<WhatsAppSendResult> sendTemplate({
    required WhatsAppTemplateId templateId,
    required String toPhone,
    required Map<String, String> variables,
  }) async {
    final normalizedPhone = PhoneUtils.normalizeIndianMobile(toPhone);
    if (normalizedPhone.isEmpty) {
      return WhatsAppSendResult.failure(
        provider: activeProvider,
        errorMessage: 'Recipient phone number is required.',
      );
    }

    final template = WhatsAppTemplates.resolve(templateId);
    final body = template.render(variables);

    return sendMessage(
      WhatsAppMessage(
        toPhone: normalizedPhone,
        body: body,
        templateId: templateId,
        variables: variables,
      ),
    );
  }

  Future<WhatsAppSendResult> sendEmployeeAssignment({
    required String employeePhone,
    required String employeeName,
    required String ticketId,
    String location = 'See employee portal',
  }) {
    return sendTemplate(
      templateId: WhatsAppTemplateId.employeeAssignment,
      toPhone: employeePhone,
      variables: {
        'employeeName': employeeName,
        'ticketId': ticketId,
        'location': location,
      },
    );
  }

  Future<WhatsAppSendResult> sendOwnerAssignment({
    required String ownerPhone,
    required String ownerName,
    required String ticketId,
    required String employeeName,
  }) {
    return sendTemplate(
      templateId: WhatsAppTemplateId.ownerAssignment,
      toPhone: ownerPhone,
      variables: {
        'ownerName': ownerName,
        'ticketId': ticketId,
        'employeeName': employeeName,
      },
    );
  }

  Future<WhatsAppSendResult> sendMessage(WhatsAppMessage message) async {
    final result = await _client.sendMessage(message);

    if (result.simulated) {
      AppLogger.i(
        'WhatsApp simulated (${result.provider.value}): ${message.body}',
      );
    } else if (!result.success) {
      AppLogger.w(
        'WhatsApp send failed (${result.provider.value}): ${result.errorMessage}',
      );
    }

    return result;
  }
}
