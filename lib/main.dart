import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:open_space_parking/core/bootstrap/app_bootstrap.dart';
import 'package:open_space_parking/core/config/environment_config.dart';
import 'package:open_space_parking/core/di/service_locator.dart';
import 'package:open_space_parking/core/firebase/firebase_bootstrap.dart';
import 'package:open_space_parking/core/providers/core_providers.dart';
import 'package:open_space_parking/core/routes/app_router.dart';
import 'package:open_space_parking/core/theme/app_theme.dart';
import 'package:open_space_parking/features/notification/presentation/widgets/notification_bootstrap.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await EnvironmentConfig.initialize();
    await configureDependencies();
  } catch (error, stack) {
    debugPrint('Startup failed: $error\n$stack');
    runApp(_StartupErrorApp(message: error.toString()));
    return;
  }

  runApp(const ProviderScope(child: OpenSpaceParkingApp()));

  // Do not block the first frame on network / Firebase setup.
  unawaited(FirebaseBootstrap.ensureInitialized());
  unawaited(AppBootstrap.initialize());
}

class _StartupErrorApp extends StatelessWidget {
  const _StartupErrorApp({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('Could not start the app.\n\n$message'),
          ),
        ),
      ),
    );
  }
}

class OpenSpaceParkingApp extends ConsumerWidget {
  const OpenSpaceParkingApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    final snackbarService = ref.watch(snackbarServiceProvider);

    return NotificationBootstrap(
      child: MaterialApp.router(
        title: 'Open Space Parking',
        debugShowCheckedModeBanner: false,
        scaffoldMessengerKey: snackbarService.messengerKey,
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: ThemeMode.system,
        themeAnimationDuration: AppTheme.animationDuration,
        themeAnimationCurve: AppTheme.animationCurve,
        routerConfig: router,
      ),
    );
  }
}
