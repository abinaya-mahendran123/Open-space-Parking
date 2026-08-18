import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:go_router/go_router.dart';



import 'package:open_space_parking/core/routes/route_paths.dart';

import 'package:open_space_parking/core/routes/role_navigation.dart';

import 'package:open_space_parking/core/theme/app_colors.dart';

import 'package:open_space_parking/features/authentication/presentation/providers/auth_state_provider.dart';



class SplashPage extends ConsumerStatefulWidget {

  const SplashPage({super.key});



  @override

  ConsumerState<SplashPage> createState() => _SplashPageState();

}



class _SplashPageState extends ConsumerState<SplashPage>

    with SingleTickerProviderStateMixin {

  late final AnimationController _pulseController;



  @override

  void initState() {

    super.initState();

    _pulseController = AnimationController(

      vsync: this,

      duration: const Duration(milliseconds: 1400),

    )..repeat(reverse: true);



    WidgetsBinding.instance.addPostFrameCallback((_) {

      _waitForSessionRestore();

    });

  }



  @override

  void dispose() {

    _pulseController.dispose();

    super.dispose();

  }



  Future<void> _waitForSessionRestore() async {

    const deadline = Duration(seconds: 3);

    final end = DateTime.now().add(deadline);



    while (mounted && DateTime.now().isBefore(end)) {

      final status = ref.read(authStateProvider).status;

      if (status != AuthStatus.unknown) {

        _goNext();

        return;

      }

      await Future<void>.delayed(const Duration(milliseconds: 50));

    }



    if (mounted) _goNext();

  }



  void _goNext() {

    if (!mounted) return;



    WidgetsBinding.instance.addPostFrameCallback((_) {

      if (!mounted) return;



      final authState = ref.read(authStateProvider);

      if (authState.status == AuthStatus.authenticated) {

        context.go(dashboardRouteForRole(authState.session?.role));

        return;

      }



      context.go(RoutePaths.authEntry);

    });

  }



  @override

  Widget build(BuildContext context) {

    final theme = Theme.of(context);

    final colorScheme = theme.colorScheme;



    return Scaffold(

      body: DecoratedBox(

        decoration: BoxDecoration(

          gradient: AppColors.backgroundGradient(theme.brightness),

        ),

        child: Center(

          child: Column(

            mainAxisAlignment: MainAxisAlignment.center,

            children: [

              ScaleTransition(

                scale: Tween<double>(begin: 0.96, end: 1.04).animate(

                  CurvedAnimation(

                    parent: _pulseController,

                    curve: Curves.easeInOut,

                  ),

                ),

                child: Container(

                  width: 88,

                  height: 88,

                  decoration: BoxDecoration(

                    gradient: AppColors.brandGradient(theme.brightness),

                    borderRadius: BorderRadius.circular(28),

                    boxShadow: [

                      BoxShadow(

                        color: colorScheme.primary.withValues(alpha: 0.4),

                        blurRadius: 28,

                        offset: const Offset(0, 12),

                      ),

                    ],

                  ),

                  child: const Icon(

                    Icons.local_parking_rounded,

                    color: Colors.white,

                    size: 44,

                  ),

                ),

              ),

              const SizedBox(height: 28),

              Text(

                'Open Space Parking',

                style: theme.textTheme.headlineSmall?.copyWith(

                  color: colorScheme.onSurface,

                ),

              ),

              const SizedBox(height: 8),

              Text(

                'Find & manage parking effortlessly',

                style: theme.textTheme.bodyMedium?.copyWith(

                  color: colorScheme.onSurfaceVariant,

                ),

              ),

              const SizedBox(height: 40),

              SizedBox(

                width: 28,

                height: 28,

                child: CircularProgressIndicator(

                  strokeWidth: 2.5,

                  color: colorScheme.primary,

                ),

              ),

            ],

          ),

        ),

      ),

    );

  }

}

