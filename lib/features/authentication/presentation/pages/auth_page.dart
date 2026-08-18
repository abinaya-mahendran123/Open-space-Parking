import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:open_space_parking/core/bootstrap/app_bootstrap.dart';
import 'package:open_space_parking/core/common/exceptions/app_exception.dart';
import 'package:open_space_parking/core/config/app_constants.dart';
import 'package:open_space_parking/core/providers/core_providers.dart';
import 'package:open_space_parking/core/routes/route_paths.dart';
import 'package:open_space_parking/core/routes/role_navigation.dart';
import 'package:open_space_parking/core/utils/phone_utils.dart';
import 'package:open_space_parking/core/utils/validators.dart';
import 'package:open_space_parking/core/widgets/buttons/primary_button.dart';
import 'package:open_space_parking/core/widgets/textfields/app_password_field.dart';
import 'package:open_space_parking/core/widgets/textfields/app_text_field.dart';
import 'package:open_space_parking/features/authentication/domain/entities/user_role.dart';
import 'package:open_space_parking/features/authentication/presentation/providers/auth_form_providers.dart';
import 'package:open_space_parking/features/authentication/presentation/providers/auth_state_provider.dart';
import 'package:open_space_parking/features/authentication/presentation/widgets/auth_method_button.dart';
import 'package:open_space_parking/features/authentication/presentation/widgets/auth_scaffold.dart';

enum _AuthSubview { picker, phone, email }

class AuthPage extends ConsumerStatefulWidget {
  const AuthPage({super.key});

  @override
  ConsumerState<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends ConsumerState<AuthPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  UserRole _signUpRole = UserRole.vehicleOwner;
  _AuthSubview _subview = _AuthSubview.picker;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _otpController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _resetPhoneFlow() {
    ref.read(phoneAuthStepProvider.notifier).state = PhoneAuthStep.enterPhone;
    ref.read(otpDevModeProvider.notifier).state = false;
    ref.read(otpDevCodeProvider.notifier).state = null;
    ref.read(verifiedPhoneProvider.notifier).state = null;
    _otpController.clear();
  }

  void _onModeChanged(AuthFormMode mode) {
    ref.read(authFormModeProvider.notifier).state = mode;
    _resetPhoneFlow();
    setState(() => _subview = _AuthSubview.picker);
  }

  void _backToPicker() {
    _resetPhoneFlow();
    setState(() => _subview = _AuthSubview.picker);
  }

  Future<void> _retryApiConnection() async {
    final loading = ref.read(authLoadingProvider.notifier);
    final snackbar = ref.read(snackbarServiceProvider);
    loading.state = true;
    try {
      final ok = await AppBootstrap.retryApi();
      if (ok) {
        snackbar.showSuccess('Connected to server. You can sign in now.');
      } else {
        snackbar.showError(
          'Still cannot reach the server. Keep USB connected and the backend running, then try again.',
        );
      }
    } finally {
      loading.state = false;
    }
  }

  Future<void> _completeAuthenticatedFlow() async {
    final role = ref.read(authStateProvider).session?.role;
    ref.read(postAuthRoleSelectionProvider.notifier).state = false;
    if (role != null) {
      ref.read(authStateProvider.notifier).setSelectedRole(role);
    }
    if (!mounted) return;
    context.go(dashboardRouteForRole(role));
  }

  Future<void> _openSecurityFromPhone() async {
    final loading = ref.read(authLoadingProvider.notifier);
    final snackbar = ref.read(snackbarServiceProvider);

    loading.state = true;
    try {
      await ref.read(authStateProvider.notifier).loginSecurity(
            email: AppConstants.defaultSecurityEmail,
            password: AppConstants.defaultSecurityPassword,
          );
      if (!mounted) return;
      await _completeAuthenticatedFlow();
    } on AppException catch (e) {
      snackbar.showError(e.message);
    } catch (_) {
      snackbar.showError('Security sign-in failed.');
    } finally {
      loading.state = false;
    }
  }

  Future<void> _sendOtp() async {
    if (!_formKey.currentState!.validate()) return;

    if (PhoneUtils.isGateSecurityPhone(_phoneController.text)) {
      await _openSecurityFromPhone();
      return;
    }

    final loading = ref.read(authLoadingProvider.notifier);
    final snackbar = ref.read(snackbarServiceProvider);

    loading.state = true;
    try {
      final result = await ref
          .read(authStateProvider.notifier)
          .sendPhoneOtp(_phoneController.text.trim());

      ref.read(phoneAuthStepProvider.notifier).state = PhoneAuthStep.enterOtp;
      ref.read(otpDevModeProvider.notifier).state = result.devMode;
      ref.read(otpDevCodeProvider.notifier).state = result.otp;
      ref.read(verifiedPhoneProvider.notifier).state = result.phone;
      if (result.devMode && result.otp != null && result.otp!.isNotEmpty) {
        _otpController.text = result.otp!;
      }

      snackbar.showSuccess(
        result.devMode
            ? (result.otp != null && result.otp!.isNotEmpty
                ? 'OTP (dev mode): ${result.otp}'
                : 'OTP sent (dev mode). Check backend console for the code.')
            : 'OTP sent to ${result.phone}',
      );
    } on AppException catch (e) {
      snackbar.showError(e.message);
    } catch (_) {
      snackbar.showError('Could not send OTP. Please try again.');
    } finally {
      loading.state = false;
    }
  }

  Future<void> _verifyOtpAndContinue() async {
    if (_otpController.text.trim().length != 6) {
      ref.read(snackbarServiceProvider).showError('Enter the 6-digit OTP.');
      return;
    }

    final mode = ref.read(authFormModeProvider);
    final loading = ref.read(authLoadingProvider.notifier);
    final snackbar = ref.read(snackbarServiceProvider);

    loading.state = true;
    try {
      await ref.read(authStateProvider.notifier).verifyPhoneOtp(
            phone: _phoneController.text.trim(),
            otp: _otpController.text.trim(),
            mode: mode,
            displayName: mode == AuthFormMode.signUp ? _nameController.text.trim() : null,
            role: mode == AuthFormMode.signUp ? _signUpRole : null,
          );

      ref.read(pendingRegistrationProvider.notifier).state = null;
      await _completeAuthenticatedFlow();
    } on AppException catch (e) {
      snackbar.showError(e.message);
    } catch (_) {
      snackbar.showError('OTP verification failed. Please try again.');
    } finally {
      loading.state = false;
    }
  }

  Future<void> _submitEmail() async {
    if (!_formKey.currentState!.validate()) return;

    final mode = ref.read(authFormModeProvider);
    final loading = ref.read(authLoadingProvider.notifier);
    final snackbar = ref.read(snackbarServiceProvider);
    final authNotifier = ref.read(authStateProvider.notifier);

    loading.state = true;
    try {
      if (mode == AuthFormMode.signUp) {
        await authNotifier.registerAccount(
          email: _emailController.text.trim(),
          password: _passwordController.text,
          displayName: _nameController.text.trim(),
          role: _signUpRole,
        );

        ref.read(pendingRegistrationProvider.notifier).state = null;
        ref.read(postAuthRoleSelectionProvider.notifier).state = false;
        ref.read(authFormModeProvider.notifier).state = AuthFormMode.signIn;
        _passwordController.clear();
        _nameController.clear();
        _backToPicker();
        snackbar.showSuccess('Account created. Sign in to continue.');
        return;
      }

      await authNotifier.loginAppUser(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
      ref.read(pendingRegistrationProvider.notifier).state = null;
      await _completeAuthenticatedFlow();
    } on AppException catch (e) {
      snackbar.showError(e.message);
    } catch (_) {
      snackbar.showError(
        mode == AuthFormMode.signUp
            ? 'Sign up failed. Please try again.'
            : 'Sign in failed. Please try again.',
      );
    } finally {
      loading.state = false;
    }
  }

  Future<void> _signInWithGoogle() async {
    final mode = ref.read(authFormModeProvider);
    final loading = ref.read(authLoadingProvider.notifier);
    final snackbar = ref.read(snackbarServiceProvider);
    final authNotifier = ref.read(authStateProvider.notifier);

    if (mode == AuthFormMode.signUp &&
        (_signUpRole == UserRole.admin || _signUpRole == UserRole.employee)) {
      snackbar.showError('Select Vehicle Owner or Land Owner.');
      return;
    }

    loading.state = true;
    try {
      if (mode == AuthFormMode.signUp) {
        await authNotifier.signUpWithGoogle(role: _signUpRole);
      } else {
        await authNotifier.signInWithGoogle();
      }

      ref.read(pendingRegistrationProvider.notifier).state = null;
      await _completeAuthenticatedFlow();
    } on AppException catch (e) {
      snackbar.showError(e.message);
    } catch (_) {
      snackbar.showError('Google sign-in failed. Please try again.');
    } finally {
      if (mounted) loading.state = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final mode = ref.watch(authFormModeProvider);
    final phoneStep = ref.watch(phoneAuthStepProvider);
    final isLoading = ref.watch(authLoadingProvider);
    final isSignUp = mode == AuthFormMode.signUp;
    final colorScheme = Theme.of(context).colorScheme;

    return AuthScaffold(
      title: 'Open Space Parking',
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              isSignUp
                  ? 'Create an account to get started.'
                  : 'Welcome back. Sign in to continue.',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 20),
            ValueListenableBuilder<ApiConnectionStatus>(
              valueListenable: AppBootstrap.apiStatus,
              builder: (context, status, _) {
                if (status != ApiConnectionStatus.offline) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: colorScheme.errorContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Cannot reach the server from this phone. Keep USB connected and the backend running, then tap Retry.',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: colorScheme.onErrorContainer,
                                ),
                          ),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: isLoading ? null : _retryApiConnection,
                              child: const Text('Retry connection'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
            SegmentedButton<AuthFormMode>(
              segments: const [
                ButtonSegment(
                  value: AuthFormMode.signIn,
                  label: Text('Sign In'),
                  icon: Icon(Icons.login),
                ),
                ButtonSegment(
                  value: AuthFormMode.signUp,
                  label: Text('Sign Up'),
                  icon: Icon(Icons.person_add_outlined),
                ),
              ],
              selected: {mode},
              onSelectionChanged: (selection) => _onModeChanged(selection.first),
            ),
            const SizedBox(height: 24),
            if (_subview != _AuthSubview.picker) ...[
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: isLoading ? null : _backToPicker,
                  icon: const Icon(Icons.arrow_back, size: 18),
                  label: const Text('Back'),
                ),
              ),
              const SizedBox(height: 8),
            ],
            if (_subview == _AuthSubview.picker) ...[
              if (isSignUp) ...[
                AppTextField(
                  controller: _nameController,
                  label: 'Full Name',
                  validator: (value) =>
                      Validators.requiredField(value, fieldName: 'Name'),
                ),
                const SizedBox(height: 12),
                _RoleSelector(
                  selectedRole: _signUpRole,
                  onChanged: (role) => setState(() => _signUpRole = role),
                ),
                const SizedBox(height: 20),
              ],
              AuthMethodButton(
                label: isSignUp ? 'Sign up with phone number' : 'Sign in with phone number',
                leading: Icon(
                  Icons.smartphone_outlined,
                  size: 22,
                  color: colorScheme.onSurface,
                ),
                onPressed: isLoading
                    ? null
                    : () => setState(() => _subview = _AuthSubview.phone),
              ),
              const SizedBox(height: 12),
              AuthMethodButton(
                label: isSignUp ? 'Sign up with Google' : 'Sign in with Google',
                leading: const GoogleLogoIcon(),
                onPressed: isLoading ? null : _signInWithGoogle,
              ),
              const SizedBox(height: 12),
              AuthMethodButton(
                label: isSignUp ? 'Sign up with email' : 'Sign in with email',
                leading: Icon(
                  Icons.mail_outline,
                  size: 22,
                  color: colorScheme.onSurface,
                ),
                onPressed: isLoading
                    ? null
                    : () => setState(() => _subview = _AuthSubview.email),
              ),
            ] else if (_subview == _AuthSubview.phone) ...[
              if (phoneStep == PhoneAuthStep.enterPhone) ...[
                AppTextField(
                  controller: _phoneController,
                  label: 'Mobile Number',
                  hint: '10-digit mobile number',
                  keyboardType: TextInputType.phone,
                  validator: Validators.mobileNumber,
                ),
                const SizedBox(height: 20),
                PrimaryButton(
                  label: 'Continue',
                  isLoading: isLoading,
                  onPressed: _sendOtp,
                ),
              ] else ...[
                Text(
                  'Enter the 6-digit code sent to ${_phoneController.text.trim()}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                ),
                if (ref.watch(otpDevModeProvider)) ...[
                  const SizedBox(height: 8),
                  Text(
                    ref.watch(otpDevCodeProvider) != null
                        ? 'Dev mode OTP: ${ref.watch(otpDevCodeProvider)}'
                        : 'Dev mode: check the backend terminal for your OTP code.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorScheme.tertiary,
                        ),
                  ),
                ],
                const SizedBox(height: 12),
                AppTextField(
                  controller: _otpController,
                  label: 'OTP',
                  hint: '6-digit code',
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  validator: (value) {
                    if (value == null || value.trim().length != 6) {
                      return 'Enter the 6-digit OTP';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                PrimaryButton(
                  label: isSignUp ? 'Verify & Create Account' : 'Verify & Sign In',
                  isLoading: isLoading,
                  onPressed: _verifyOtpAndContinue,
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: isLoading ? null : _resetPhoneFlow,
                  child: const Text('Resend OTP'),
                ),
              ],
            ] else ...[
              AppTextField(
                controller: _emailController,
                label: 'Email',
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
                label: isSignUp ? 'Create Account' : 'Continue',
                isLoading: isLoading,
                onPressed: _submitEmail,
              ),
              if (!isSignUp) ...[
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => context.go(RoutePaths.forgotPassword),
                  child: const Text('Forgot Password?'),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _RoleSelector extends StatelessWidget {
  const _RoleSelector({
    required this.selectedRole,
    required this.onChanged,
  });

  final UserRole selectedRole;
  final ValueChanged<UserRole> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text.rich(
          TextSpan(
            style: Theme.of(context).textTheme.titleSmall,
            children: const [
              TextSpan(text: 'I'),
              TextSpan(text: ' '),
              TextSpan(text: 'am'),
              TextSpan(text: ' '),
              TextSpan(text: 'a'),
            ],
          ),
        ),
        const SizedBox(height: 8),
        SegmentedButton<UserRole>(
          segments: const [
            ButtonSegment(
              value: UserRole.vehicleOwner,
              label: Text('Vehicle Owner'),
              icon: Icon(Icons.directions_car_filled_outlined),
            ),
            ButtonSegment(
              value: UserRole.landOwner,
              label: Text('Land Owner'),
              icon: Icon(Icons.domain),
            ),
          ],
          selected: {selectedRole},
          onSelectionChanged: (selection) => onChanged(selection.first),
        ),
      ],
    );
  }
}
