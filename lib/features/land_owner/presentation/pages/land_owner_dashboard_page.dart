import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:open_space_parking/core/routes/route_paths.dart';
import 'package:open_space_parking/core/theme/app_spacing.dart';
import 'package:open_space_parking/core/widgets/animations/app_fade_slide.dart';
import 'package:open_space_parking/core/widgets/cards/app_action_card.dart';
import 'package:open_space_parking/core/widgets/layout/app_page_header.dart';
import 'package:open_space_parking/core/widgets/layout/responsive_page.dart';
import 'package:open_space_parking/features/authentication/presentation/providers/auth_state_provider.dart';
import 'package:open_space_parking/features/notification/domain/entities/notification_recipient_type.dart';
import 'package:open_space_parking/features/notification/presentation/widgets/notification_badge.dart';

class LandOwnerDashboardPage extends ConsumerWidget {
  const LandOwnerDashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authStateProvider);
    final ownerId = auth.session?.userId ?? '';
    final name = auth.session?.greetingName ?? 'Land Owner';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          NotificationBadge(
            recipientId: ownerId,
            recipientType: NotificationRecipientType.landOwner,
            child: IconButton(
              onPressed: () => context.go(RoutePaths.landOwnerNotifications),
              icon: const Icon(Icons.notifications_outlined),
            ),
          ),
        ],
      ),
      body: ResponsivePage(
        maxWidth: 800,
        scrollable: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppPageHeader(
              title: 'Hello, $name',
              subtitle:
                  'Choose an option to get started with your parking request.',
            ),
            const SizedBox(height: AppSpacing.sectionGap),
            AppStaggeredList(
              children: [
                AppActionCard(
                  icon: Icons.construction_rounded,
                  title: 'I Want to Build Parking',
                  subtitle:
                      'Submit a new request to build parking on your land with admin approval.',
                  onTap: () => context.push(RoutePaths.landOwnerBuildParking),
                ),
                AppActionCard(
                  icon: Icons.local_parking_rounded,
                  title: 'Already Have Parking',
                  subtitle:
                      'Register your existing parking facility for listing and management.',
                  onTap: () => context.push(RoutePaths.landOwnerExistingParking),
                ),
                AppActionCard(
                  icon: Icons.qr_code_scanner,
                  title: 'Gate security scan',
                  subtitle:
                      'Scan a driver’s QR to start or stop a parking session.',
                  onTap: () => context.push(RoutePaths.securityScan),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
