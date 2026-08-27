import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:open_space_parking/core/routes/route_paths.dart';
import 'package:open_space_parking/core/widgets/buttons/primary_button.dart';
import 'package:open_space_parking/features/authentication/presentation/widgets/auth_scaffold.dart';

class AuthWelcomePage extends StatelessWidget {
  const AuthWelcomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return AuthScaffold(
      title: 'Open Space Parking',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Find and manage parking effortlessly.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 32),
          PrimaryButton(
            label: 'Sign In',
            icon: Icons.login,
            onPressed: () => context.go(RoutePaths.login),
          ),
          const SizedBox(height: 12),
          PrimaryButton(
            label: 'Sign Up',
            variant: PrimaryButtonVariant.outlined,
            icon: Icons.person_add_outlined,
            onPressed: () => context.go(RoutePaths.register),
          ),
        ],
      ),
    );
  }
}
