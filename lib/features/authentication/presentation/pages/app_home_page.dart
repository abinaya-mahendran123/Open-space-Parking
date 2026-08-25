import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:open_space_parking/core/domain/domain_extensions.dart';
import 'package:open_space_parking/core/widgets/dialogs/app_dialogs.dart';
import 'package:open_space_parking/features/authentication/presentation/providers/auth_state_provider.dart';

class AppHomePage extends ConsumerWidget {
  const AppHomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authStateProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Open Space Parking'),
        actions: [
          IconButton(
            onPressed: () async {
              final confirmed = await AppDialogs.confirmLogout(context);
              if (!confirmed || !context.mounted) return;
              await ref.read(authStateProvider.notifier).logout();
            },
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: Center(
        child: Text(
          'Authenticated as ${auth.session?.role.label ?? 'Unknown'}',
          style: Theme.of(context).textTheme.titleMedium,
        ),
      ),
    );
  }
}
