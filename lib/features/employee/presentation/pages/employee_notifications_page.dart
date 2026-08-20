import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:open_space_parking/features/authentication/presentation/providers/auth_state_provider.dart';
import 'package:open_space_parking/features/employee/presentation/widgets/employee_sub_page_frame.dart';
import 'package:open_space_parking/features/notification/domain/entities/notification_recipient_type.dart';
import 'package:open_space_parking/features/notification/presentation/widgets/notification_history_view.dart';

class EmployeeNotificationsPage extends ConsumerWidget {
  const EmployeeNotificationsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final employeeId = ref.watch(authStateProvider).session?.userId ?? '';

    return EmployeeSubPageFrame(
      title: 'Notifications',
      child: NotificationHistoryView(
        recipientId: employeeId,
        recipientType: NotificationRecipientType.employee,
      ),
    );
  }
}
