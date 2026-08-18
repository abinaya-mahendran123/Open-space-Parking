import 'package:equatable/equatable.dart';

import 'package:open_space_parking/core/whatsapp/domain/entities/whatsapp_provider_type.dart';
import 'package:open_space_parking/core/whatsapp/domain/entities/whatsapp_template_id.dart';

class WhatsAppMessage extends Equatable {
  const WhatsAppMessage({
    required this.toPhone,
    required this.body,
    this.templateId,
    this.variables = const {},
  });

  final String toPhone;
  final String body;
  final WhatsAppTemplateId? templateId;
  final Map<String, String> variables;

  @override
  List<Object?> get props => [toPhone, body, templateId, variables];
}

class WhatsAppSendResult extends Equatable {
  const WhatsAppSendResult({
    required this.success,
    required this.provider,
    this.messageId,
    this.errorMessage,
    this.simulated = false,
  });

  final bool success;
  final WhatsAppProviderType provider;
  final String? messageId;
  final String? errorMessage;
  final bool simulated;

  factory WhatsAppSendResult.simulated({
    required WhatsAppProviderType provider,
    String? messageId,
  }) {
    return WhatsAppSendResult(
      success: true,
      provider: provider,
      messageId: messageId ?? 'simulated-${DateTime.now().millisecondsSinceEpoch}',
      simulated: true,
    );
  }

  factory WhatsAppSendResult.failure({
    required WhatsAppProviderType provider,
    required String errorMessage,
  }) {
    return WhatsAppSendResult(
      success: false,
      provider: provider,
      errorMessage: errorMessage,
    );
  }

  @override
  List<Object?> get props =>
      [success, provider, messageId, errorMessage, simulated];
}
