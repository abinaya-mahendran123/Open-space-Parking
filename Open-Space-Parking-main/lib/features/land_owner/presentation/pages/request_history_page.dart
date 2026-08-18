import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:open_space_parking/core/widgets/errors/app_error_widget.dart';
import 'package:open_space_parking/core/widgets/loading/app_loading_widget.dart';
import 'package:open_space_parking/features/authentication/presentation/providers/auth_state_provider.dart';
import 'package:open_space_parking/features/land_owner/presentation/providers/land_owner_providers.dart';
import 'package:open_space_parking/features/land_owner/presentation/widgets/request_history_card.dart';

class RequestHistoryPage extends ConsumerWidget {
  const RequestHistoryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ownerId = ref.watch(authStateProvider).session?.userId ?? '';
    final historyAsync = ref.watch(requestHistoryProvider(ownerId));

    return Scaffold(
      appBar: AppBar(title: const Text('Request History')),
      body: historyAsync.when(
        loading: () => const AppLoadingWidget(message: 'Loading requests...'),
        error: (e, _) => AppErrorWidget(
          message: 'Failed to load request history',
          onRetry: () => ref.invalidate(requestHistoryProvider(ownerId)),
        ),
        data: (requests) {
          if (requests.isEmpty) {
            return const Center(
              child: Text('No requests submitted yet.'),
            );
          }

          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(requestHistoryProvider(ownerId)),
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: requests.length,
              itemBuilder: (context, index) =>
                  RequestHistoryCard(request: requests[index]),
            ),
          );
        },
      ),
    );
  }
}
