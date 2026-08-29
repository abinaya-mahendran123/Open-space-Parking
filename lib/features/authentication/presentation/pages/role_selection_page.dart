import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:open_space_parking/core/common/exceptions/app_exception.dart';
import 'package:open_space_parking/core/providers/core_providers.dart';
import 'package:open_space_parking/core/routes/route_paths.dart';
import 'package:open_space_parking/core/routes/role_navigation.dart';
import 'package:open_space_parking/core/theme/app_colors.dart';
import 'package:open_space_parking/core/widgets/buttons/primary_button.dart';
import 'package:open_space_parking/features/authentication/domain/entities/user_role.dart';
import 'package:open_space_parking/features/authentication/presentation/providers/auth_form_providers.dart';
import 'package:open_space_parking/features/authentication/presentation/providers/auth_state_provider.dart';
import 'package:open_space_parking/features/authentication/presentation/widgets/auth_scaffold.dart';

class RoleSelectionPage extends ConsumerStatefulWidget {
  const RoleSelectionPage({super.key});

  @override
  ConsumerState<RoleSelectionPage> createState() => _RoleSelectionPageState();
}

class _RoleSelectionPageState extends ConsumerState<RoleSelectionPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  void _bootstrap() {
    if (!mounted) return;

    final isPostAuth = ref.read(postAuthRoleSelectionProvider);
    final isAuthenticated =
        ref.read(authStateProvider).status == AuthStatus.authenticated;

    if (!isPostAuth && !isAuthenticated) {
      context.go(RoutePaths.authEntry);
      return;
    }

    final sessionRole = ref.read(authStateProvider).session?.role;
    if (ref.read(authStateProvider).selectedRole == null && sessionRole != null) {
      ref.read(authStateProvider.notifier).setSelectedRole(sessionRole);
    } else if (ref.read(authStateProvider).selectedRole == null) {
      ref.read(authStateProvider.notifier).setSelectedRole(UserRole.vehicleOwner);
    }
  }

  Future<void> _submit() async {
    final selectedRole = ref.read(authStateProvider).selectedRole;

    if (selectedRole == null ||
        (selectedRole != UserRole.vehicleOwner &&
            selectedRole != UserRole.landOwner)) {
      ref.read(snackbarServiceProvider).showError('Please choose a role.');
      return;
    }

    final loading = ref.read(authLoadingProvider.notifier);
    final snackbar = ref.read(snackbarServiceProvider);

    loading.state = true;
    try {
      ref.read(postAuthRoleSelectionProvider.notifier).state = false;

      if (!mounted) return;
      context.go(onboardingRouteForRole(selectedRole));
    } on AppException catch (e) {
      snackbar.showError(e.message);
    } catch (_) {
      snackbar.showError('Could not continue. Please try again.');
    } finally {
      loading.state = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAuthenticated =
        ref.watch(authStateProvider).status == AuthStatus.authenticated;
    final isPostAuth = ref.watch(postAuthRoleSelectionProvider);

    if (!isPostAuth && !isAuthenticated) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final selectedRole = ref.watch(authStateProvider).selectedRole;
    final isLoading = ref.watch(authLoadingProvider);

    return AuthScaffold(
      title: 'Choose Your Role',
      style: AuthScaffoldStyle.form,
      subtitle: 'Select how you want to use Open Space Parking',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _RoleCard(
            role: UserRole.vehicleOwner,
            isSelected: selectedRole == UserRole.vehicleOwner,
            onTap: () => ref
                .read(authStateProvider.notifier)
                .setSelectedRole(UserRole.vehicleOwner),
          ),
          const SizedBox(height: 12),
          _RoleCard(
            role: UserRole.landOwner,
            isSelected: selectedRole == UserRole.landOwner,
            onTap: () => ref
                .read(authStateProvider.notifier)
                .setSelectedRole(UserRole.landOwner),
          ),
          const SizedBox(height: 28),
          PrimaryButton(
            label: 'Continue',
            isLoading: isLoading,
            onPressed: _submit,
          ),
        ],
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({
    required this.role,
    required this.isSelected,
    required this.onTap,
  });

  final UserRole role;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isLandOwner = role == UserRole.landOwner;

    return Material(
      color: isSelected
          ? (Theme.of(context).brightness == Brightness.dark
              ? colorScheme.primaryContainer.withValues(alpha: 0.35)
              : AppColors.brandBlueSoft)
          : colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected ? AppColors.primary : colorScheme.outlineVariant,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.primary.withValues(alpha: 0.12)
                      : colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isLandOwner
                      ? Icons.domain
                      : Icons.directions_car_filled_outlined,
                  size: 26,
                  color: isSelected
                      ? colorScheme.primary
                      : colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isLandOwner ? 'Land Owner' : 'Vehicle Owner',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: colorScheme.onSurface,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isLandOwner
                          ? 'List parking and submit build requests'
                          : 'Search and book parking near you',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
              ),
              Icon(
                isSelected ? Icons.check_circle : Icons.circle_outlined,
                color: isSelected ? colorScheme.primary : colorScheme.outline,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
