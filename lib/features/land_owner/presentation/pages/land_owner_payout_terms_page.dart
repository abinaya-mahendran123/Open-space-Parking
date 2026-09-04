import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:open_space_parking/core/common/exceptions/app_exception.dart';
import 'package:open_space_parking/core/providers/core_providers.dart';
import 'package:open_space_parking/core/routes/route_paths.dart';
import 'package:open_space_parking/core/theme/app_spacing.dart';
import 'package:open_space_parking/core/widgets/buttons/primary_button.dart';
import 'package:open_space_parking/features/authentication/presentation/providers/auth_state_provider.dart';
import 'package:open_space_parking/features/land_owner/domain/entities/land_owner_payout_terms.dart';
import 'package:open_space_parking/features/land_owner/presentation/providers/land_owner_providers.dart';

/// Compact popup-style terms — must accept before land-owner features.
class LandOwnerPayoutTermsPage extends ConsumerStatefulWidget {
  const LandOwnerPayoutTermsPage({
    super.key,
    this.afterAcceptRoute = RoutePaths.landOwnerDashboard,
  });

  final String afterAcceptRoute;

  @override
  ConsumerState<LandOwnerPayoutTermsPage> createState() =>
      _LandOwnerPayoutTermsPageState();
}

class _LandOwnerPayoutTermsPageState
    extends ConsumerState<LandOwnerPayoutTermsPage> {
  bool _accepted = false;
  bool _saving = false;

  Future<void> _accept() async {
    if (!_accepted) return;
    final ownerId = ref.read(authStateProvider).session?.userId ?? '';
    if (ownerId.isEmpty) return;

    setState(() => _saving = true);
    try {
      await ref.read(landOwnerRepositoryProvider).acceptPayoutTerms(ownerId);
      ref.invalidate(landOwnerPayoutTermsAcceptedProvider(ownerId));
      if (!mounted) return;
      context.go(widget.afterAcceptRoute);
    } on AppException catch (e) {
      ref.read(snackbarServiceProvider).showError(e.message);
    } catch (_) {
      ref.read(snackbarServiceProvider).showError(
            'Could not save. Please try again.',
          );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: Colors.black.withValues(alpha: 0.45),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Material(
                color: colorScheme.surface,
                elevation: 8,
                shadowColor: colorScheme.shadow.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(20),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: colorScheme.primary.withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.account_balance_wallet_outlined,
                            color: colorScheme.primary,
                            size: 28,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        LandOwnerPayoutTerms.title,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        LandOwnerPayoutTerms.subtitle,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 20),
                      ...LandOwnerPayoutTerms.points.map(
                        (point) => Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.check_circle,
                                size: 18,
                                color: colorScheme.primary,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      point.title,
                                      style:
                                          theme.textTheme.titleSmall?.copyWith(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      point.body,
                                      style:
                                          theme.textTheme.bodyMedium?.copyWith(
                                        height: 1.35,
                                        color: colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      InkWell(
                        onTap: _saving
                            ? null
                            : () => setState(() => _accepted = !_accepted),
                        borderRadius: BorderRadius.circular(8),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            children: [
                              Checkbox(
                                value: _accepted,
                                onChanged: _saving
                                    ? null
                                    : (v) =>
                                        setState(() => _accepted = v ?? false),
                              ),
                              const Expanded(
                                child: Text(
                                  LandOwnerPayoutTerms.checkboxLabel,
                                  style: TextStyle(fontWeight: FontWeight.w500),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      PrimaryButton(
                        label: 'Accept & continue',
                        isLoading: _saving,
                        onPressed: _accepted && !_saving ? _accept : null,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Shows [child] only after payout terms are accepted; otherwise the terms popup.
class LandOwnerTermsGate extends ConsumerWidget {
  const LandOwnerTermsGate({
    super.key,
    required this.child,
    this.afterAcceptRoute = RoutePaths.landOwnerDashboard,
  });

  final Widget child;
  final String afterAcceptRoute;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ownerId = ref.watch(authStateProvider).session?.userId ?? '';
    if (ownerId.isEmpty) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final termsAsync = ref.watch(landOwnerPayoutTermsAcceptedProvider(ownerId));

    return termsAsync.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (_, __) => LandOwnerPayoutTermsPage(
        afterAcceptRoute: afterAcceptRoute,
      ),
      data: (accepted) {
        if (accepted) return child;
        return LandOwnerPayoutTermsPage(afterAcceptRoute: afterAcceptRoute);
      },
    );
  }
}
