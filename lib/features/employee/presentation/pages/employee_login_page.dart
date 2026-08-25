import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:open_space_parking/core/common/exceptions/app_exception.dart';
import 'package:open_space_parking/core/providers/core_providers.dart';
import 'package:open_space_parking/core/routes/route_paths.dart';
import 'package:open_space_parking/core/utils/phone_utils.dart';
import 'package:open_space_parking/core/utils/validators.dart';
import 'package:open_space_parking/core/widgets/buttons/primary_button.dart';
import 'package:open_space_parking/core/widgets/textfields/app_password_field.dart';
import 'package:open_space_parking/core/widgets/textfields/app_text_field.dart';
import 'package:open_space_parking/features/authentication/presentation/providers/auth_form_providers.dart';
import 'package:open_space_parking/features/authentication/presentation/providers/auth_state_provider.dart';
import 'package:open_space_parking/features/authentication/presentation/widgets/auth_scaffold.dart';

class EmployeeLoginPage extends ConsumerStatefulWidget {
  const EmployeeLoginPage({super.key});

  @override
  ConsumerState<EmployeeLoginPage> createState() => _EmployeeLoginPageState();
}

class _EmployeeLoginPageState extends ConsumerState<EmployeeLoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final phone = _phoneController.text.trim();
    final password = _passwordController.text.trim();
    final expected = PhoneUtils.lastSixDigits(phone);
    if (password != expected) {
      ref.read(snackbarServiceProvider).showError(
            'Enter the last 6 digits of this mobile number.',
          );
      return;
    }

    final loading = ref.read(authLoadingProvider.notifier);
    loading.state = true;
    try {
      await ref.read(authStateProvider.notifier).loginEmployee(
            phone: phone,
            password: password,
          );
      if (!mounted) return;
      context.go(RoutePaths.employeeDashboard);
    } on AppException catch (e) {
      ref.read(snackbarServiceProvider).showError(e.message);
    } catch (_) {
      ref.read(snackbarServiceProvider).showError('Employee login failed.');
    } finally {
      loading.state = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(authLoadingProvider);

    return AuthScaffold(
      title: 'Employee Portal',
      onBack: () => context.go(RoutePaths.authEntry),
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            Text(
              'Password is the last 6 digits of the employee mobile number.',
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            AppTextField(
              controller: _phoneController,
              label: 'Mobile Number',
              hint: '10-digit mobile number',
              keyboardType: TextInputType.phone,
              validator: Validators.mobileNumber,
            ),
            const SizedBox(height: 12),
            AppPasswordField(
              controller: _passwordController,
              label: 'Password (last 6 digits)',
              validator: (value) {
                if (value == null || value.trim().length != 6) {
                  return 'Enter the last 6 digits';
                }
                return null;
              },
            ),
            const SizedBox(height: 20),
            PrimaryButton(
              label: 'Login as Employee',
              isLoading: isLoading,
              onPressed: _submit,
            ),
          ],
        ),
      ),
    );
  }
}
