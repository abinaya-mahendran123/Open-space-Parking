import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:open_space_parking/features/authentication/presentation/providers/auth_state_provider.dart';
import 'package:open_space_parking/features/notification/presentation/providers/notification_providers.dart';

/// Initializes push notification bindings and handles notification tap navigation.
class NotificationBootstrap extends ConsumerStatefulWidget {
  const NotificationBootstrap({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  ConsumerState<NotificationBootstrap> createState() =>
      _NotificationBootstrapState();
}

class _NotificationBootstrapState extends ConsumerState<NotificationBootstrap> {
  @override
  void initState() {
    super.initState();
    Future.microtask(_syncAuthBinding);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(authStateProvider, (_, next) {
      if (next.status == AuthStatus.authenticated && next.session != null) {
        bindNotificationUser(
          ref,
          userId: next.session!.userId,
          role: next.session!.role,
        );
      } else if (next.status == AuthStatus.unauthenticated) {
        unbindNotificationUser(ref);
      }
    });

    ref.listen(notificationTapProvider, (_, next) {
      next.whenData((payload) {
        final route = payload.route;
        if (route != null && route.isNotEmpty && mounted) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) context.go(route);
          });
        }
      });
    });

    return widget.child;
  }

  Future<void> _syncAuthBinding() {
    final auth = ref.read(authStateProvider);
    if (auth.status == AuthStatus.authenticated && auth.session != null) {
      return bindNotificationUser(
        ref,
        userId: auth.session!.userId,
        role: auth.session!.role,
      );
    }
    return Future.value();
  }
}
