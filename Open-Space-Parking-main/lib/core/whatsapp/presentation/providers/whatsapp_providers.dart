import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:get_it/get_it.dart';

import 'package:open_space_parking/core/whatsapp/data/services/whatsapp_service.dart';
import 'package:open_space_parking/core/whatsapp/domain/entities/whatsapp_message.dart';
import 'package:open_space_parking/core/whatsapp/domain/entities/whatsapp_provider_type.dart';
import 'package:open_space_parking/core/whatsapp/domain/entities/whatsapp_template_id.dart';

final whatsAppServiceProvider = Provider<WhatsAppService>(
  (ref) => GetIt.I<WhatsAppService>(),
);

final whatsAppProviderTypeProvider = Provider<WhatsAppProviderType>(
  (ref) => ref.watch(whatsAppServiceProvider).activeProvider,
);

final whatsAppSendControllerProvider = StateNotifierProvider.autoDispose<
    WhatsAppSendController, AsyncValue<WhatsAppSendResult?>>(
  (ref) => WhatsAppSendController(ref.watch(whatsAppServiceProvider)),
);

class WhatsAppSendController
    extends StateNotifier<AsyncValue<WhatsAppSendResult?>> {
  WhatsAppSendController(this._service) : super(const AsyncData(null));

  final WhatsAppService _service;

  Future<WhatsAppSendResult?> sendEmployeeAssignment({
    required String employeePhone,
    required String employeeName,
    required String ticketId,
    String location = 'See employee portal',
  }) async {
    state = const AsyncLoading();
    try {
      final result = await _service.sendEmployeeAssignment(
        employeePhone: employeePhone,
        employeeName: employeeName,
        ticketId: ticketId,
        location: location,
      );
      state = AsyncData(result);
      return result;
    } catch (e, st) {
      state = AsyncError(e, st);
      return null;
    }
  }

  Future<WhatsAppSendResult?> sendOwnerAssignment({
    required String ownerPhone,
    required String ownerName,
    required String ticketId,
    required String employeeName,
  }) async {
    state = const AsyncLoading();
    try {
      final result = await _service.sendOwnerAssignment(
        ownerPhone: ownerPhone,
        ownerName: ownerName,
        ticketId: ticketId,
        employeeName: employeeName,
      );
      state = AsyncData(result);
      return result;
    } catch (e, st) {
      state = AsyncError(e, st);
      return null;
    }
  }

  Future<WhatsAppSendResult?> sendTemplate({
    required WhatsAppTemplateId templateId,
    required String toPhone,
    required Map<String, String> variables,
  }) async {
    state = const AsyncLoading();
    try {
      final result = await _service.sendTemplate(
        templateId: templateId,
        toPhone: toPhone,
        variables: variables,
      );
      state = AsyncData(result);
      return result;
    } catch (e, st) {
      state = AsyncError(e, st);
      return null;
    }
  }
}
