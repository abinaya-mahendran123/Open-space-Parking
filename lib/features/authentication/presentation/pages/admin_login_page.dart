import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:open_space_parking/core/config/app_constants.dart';
import 'package:open_space_parking/core/common/exceptions/app_exception.dart';
import 'package:open_space_parking/core/providers/core_providers.dart';
import 'package:open_space_parking/core/routes/route_paths.dart';
import 'package:open_space_parking/core/utils/validators.dart';
import 'package:open_space_parking/core/widgets/buttons/primary_button.dart';
import 'package:open_space_parking/core/widgets/textfields/app_password_field.dart';
import 'package:open_space_parking/core/widgets/textfields/app_text_field.dart';
import 'package:open_space_parking/features/authentication/presentation/providers/auth_form_providers.dart';
import 'package:open_space_parking/features/authentication/presentation/providers/auth_state_provider.dart';
import 'package:open_space_parking/features/authentication/presentation/widgets/auth_scaffold.dart';

class AdminLoginPage extends ConsumerStatefulWidget {
  const AdminLoginPage({super.key});

  @override
  ConsumerState<AdminLoginPage> createState() => _AdminLoginPageState();
}

class _AdminLoginPageState extends ConsumerState<AdminLoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController(
    text: AppConstants.defaultAdminEmail,
  );
  final _passwordController = TextEditingController(
    text: AppConstants.defaultAdminPassword,
  );

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final loading = ref.read(authLoadingProvider.notifier);
    final authNotifier = ref.read(authStateProvider.notifier);
    final snackbar = ref.read(snackbarServiceProvider);

    loading.state = true;
    try {
      await authNotifier.loginAdmin(
        email: _emailController.text,
        password: _passwordController.text,
      );
      if (!mounted) return;
      context.go(RoutePaths.adminPortal);
    } on AppException catch (e) {
      snackbar.showError(e.message);
    } catch (_) {
      snackbar.showError('Admin login failed.');
    } finally {
      loading.state = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(authLoadingProvider);

    return AuthScaffold(
      title: 'Admin Portal Login',
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            AppTextField(
              controller: _emailController,
              label: 'Admin Email',
              keyboardType: TextInputType.emailAddress,
              validator: Validators.email,
            ),
            const SizedBox(height: 12),
            AppPasswordField(
              controller: _passwordController,
              label: 'Password',
              validator: (value) => Validators.minLength(value, 8),
            ),
            const SizedBox(height: 20),
            PrimaryButton(
              label: 'Login as Admin',
              isLoading: isLoading,
              onPressed: _submit,
            ),
          ],
        ),
      ),
    );
  }
}
