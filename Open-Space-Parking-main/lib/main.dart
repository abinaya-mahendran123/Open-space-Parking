import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:open_space_parking/core/bootstrap/app_bootstrap.dart';
import 'package:open_space_parking/core/config/environment_config.dart';
import 'package:open_space_parking/core/di/service_locator.dart';
import 'package:open_space_parking/core/providers/core_providers.dart';
import 'package:open_space_parking/core/routes/app_router.dart';
import 'package:open_space_parking/core/theme/app_theme.dart';
import 'package:open_space_parking/features/notification/presentation/widgets/notification_bootstrap.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await EnvironmentConfig.initialize();
  await configureDependencies();

  runApp(const ProviderScope(child: OpenSpaceParkingApp()));

  // Do not block the first frame on network / Firebase setup.
  unawaited(AppBootstrap.initialize());
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
