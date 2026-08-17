import 'package:open_space_parking/core/whatsapp/domain/entities/whatsapp_message.dart';

abstract class WhatsAppApiClient {
  WhatsAppApiClient({required this.isConfigured});

  final bool isConfigured;

  Future<WhatsAppSendResult> sendMessage(WhatsAppMessage message);
}
