import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:open_space_parking/core/common/exceptions/app_exception.dart';
import 'package:open_space_parking/core/config/app_constants.dart';
import 'package:open_space_parking/core/providers/core_providers.dart';
import 'package:open_space_parking/core/routes/route_paths.dart';
import 'package:open_space_parking/core/utils/validators.dart';
import 'package:open_space_parking/core/widgets/buttons/primary_button.dart';
import 'package:open_space_parking/core/widgets/textfields/app_password_field.dart';
import 'package:open_space_parking/core/widgets/textfields/app_text_field.dart';
import 'package:open_space_parking/features/authentication/presentation/providers/auth_form_providers.dart';
import 'package:open_space_parking/features/authentication/presentation/providers/auth_state_provider.dart';
import 'package:open_space_parking/features/authentication/presentation/widgets/auth_scaffold.dart';

class SecurityLoginPage extends ConsumerStatefulWidget {
  const SecurityLoginPage({super.key, this.onBack});

  final VoidCallback? onBack;

  @override
  ConsumerState<SecurityLoginPage> createState() => _SecurityLoginPageState();
}

class _SecurityLoginPageState extends ConsumerState<SecurityLoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController(
    text: AppConstants.defaultSecurityEmail,
  );
  final _passwordController = TextEditingController(
    text: AppConstants.defaultSecurityPassword,
  );

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _goBack() {
    if (widget.onBack != null) {
      widget.onBack!();
      return;
    }
    context.go(RoutePaths.authEntry);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final loading = ref.read(authLoadingProvider.notifier);
    loading.state = true;
    try {
      await ref.read(authStateProvider.notifier).loginSecurity(
            email: _emailController.text,
            password: _passwordController.text,
          );
      if (!mounted) return;
      context.go(RoutePaths.securityScan);
    } on AppException catch (e) {
      ref.read(snackbarServiceProvider).showError(e.message);
    } catch (_) {
      ref.read(snackbarServiceProvider).showError('Security login failed.');
    } finally {
      loading.state = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(authLoadingProvider);

    return AuthScaffold(
      title: 'Security Gate Login',
      onBack: _goBack,
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            Text(
              'For gate staff only. Scan driver QR codes to start and stop parking.',
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            AppTextField(
              controller: _emailController,
              label: 'Security Email',
              keyboardType: TextInputType.emailAddress,
              validator: Validators.email,
            ),
            const SizedBox(height: 12),
            AppPasswordField(
              controller: _passwordController,
              label: 'Password',
              validator: (value) => Validators.minLength(value, 8),
            ),
            const SizedBox(height: 8),
            Text(
              'Demo: ${AppConstants.defaultSecurityEmail} / ${AppConstants.defaultSecurityPassword}',
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            PrimaryButton(
              label: 'Open gate scanner',
              isLoading: isLoading,
              onPressed: _submit,
            ),
            TextButton.icon(
              onPressed: isLoading ? null : _goBack,
              icon: const Icon(Icons.arrow_back),
              label: const Text('Back'),
            ),
          ],
        ),
      ),
    );
  }
}
