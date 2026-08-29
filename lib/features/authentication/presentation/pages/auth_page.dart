import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:open_space_parking/core/common/exceptions/app_exception.dart';
import 'package:open_space_parking/core/services/api/account_check_service.dart';
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
  const AuthPage({super.key, required this.mode});

  final AuthFormMode mode;

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

  final _employeePasswordController = TextEditingController();

  UserRole _signUpRole = UserRole.vehicleOwner;
  _AuthSubview _subview = _AuthSubview.picker;
  Timer? _resendCooldownTimer;
  int _resendCooldownSeconds = 0;
  String? _checkingAccountLabel;

  String _formattedPhone(String phone) {
    final normalized = PhoneUtils.normalizeIndianMobile(phone);
    final digits = PhoneUtils.digitsOnly(normalized);
    final lastTen = digits.length >= 10
        ? digits.substring(digits.length - 10)
        : digits;
    if (lastTen.length == 10) {
      return '+91 ${lastTen.substring(0, 5)} ${lastTen.substring(5)}';
    }
    return normalized.isNotEmpty ? normalized : phone.trim();
  }

  void _startResendCooldown([int seconds = 30]) {
    _resendCooldownTimer?.cancel();
    setState(() => _resendCooldownSeconds = seconds);
    _resendCooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_resendCooldownSeconds <= 1) {
        timer.cancel();
        setState(() => _resendCooldownSeconds = 0);
        return;
      }
      setState(() => _resendCooldownSeconds -= 1);
    });
  }

  @override
  void initState() {
    super.initState();
    // After security/employee logout, clear leftover phone-step state so
    // the welcome screen shows instead of the previous password form.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (ref.read(authStateProvider).status == AuthStatus.unauthenticated) {
        _resetPhoneFlow();
        if (_subview != _AuthSubview.picker) {
          setState(() => _subview = _AuthSubview.picker);
        }
      }
    });
  }

  @override
  void dispose() {
    _resendCooldownTimer?.cancel();
    _nameController.dispose();
    _phoneController.dispose();
    _otpController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _employeePasswordController.dispose();
    super.dispose();
  }

  void _resetPhoneFlow() {
    ref.read(phoneAuthStepProvider.notifier).state = PhoneAuthStep.enterPhone;
    ref.read(verifiedPhoneProvider.notifier).state = null;
    _otpController.clear();
    _employeePasswordController.clear();
    _resendCooldownTimer?.cancel();
    _resendCooldownSeconds = 0;
    _checkingAccountLabel = null;
  }

  void _backToWelcome() {
    _resetPhoneFlow();
    if (!mounted) return;
    context.go(RoutePaths.authEntry);
  }

  void _backToPicker() {
    _resetPhoneFlow();
    setState(() => _subview = _AuthSubview.picker);
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
    ref.read(phoneAuthStepProvider.notifier).state =
        PhoneAuthStep.enterSecurityPassword;
    ref.read(verifiedPhoneProvider.notifier).state =
        PhoneUtils.normalizeIndianMobile(_phoneController.text.trim());
    _employeePasswordController.clear();
  }

  Future<void> _continueWithPhone() async {
    if (!_formKey.currentState!.validate()) return;

    final loading = ref.read(authLoadingProvider.notifier);
    final snackbar = ref.read(snackbarServiceProvider);

    loading.state = true;
    setState(() => _checkingAccountLabel = 'Checking account...');
    try {
      final accountType = await ref
          .read(authStateProvider.notifier)
          .checkPhoneAccount(_phoneController.text.trim());

      if (accountType == PhoneAccountType.security) {
        await _openSecurityFromPhone();
        return;
      }

      if (accountType == PhoneAccountType.employee) {
        ref.read(phoneAuthStepProvider.notifier).state =
            PhoneAuthStep.enterEmployeePassword;
        ref.read(verifiedPhoneProvider.notifier).state =
            PhoneUtils.normalizeIndianMobile(_phoneController.text.trim());
        return;
      }

      await _sendOtp();
    } on AppException catch (e) {
      snackbar.showError(e.message);
    } catch (_) {
      snackbar.showError(
        'Unable to connect. Please check your internet connection and try again.',
      );
    } finally {
      if (mounted) {
        setState(() => _checkingAccountLabel = null);
      }
      loading.state = false;
    }
  }

  Future<void> _submitSecurityPassword() async {
    final phone = _phoneController.text.trim();
    final password = _employeePasswordController.text.trim();
    final expected = PhoneUtils.lastFourDigits(phone);
    if (password.length != 4 || password != expected) {
      ref.read(snackbarServiceProvider).showError(
            'Enter the last 4 digits of this mobile number.',
          );
      return;
    }

    final loading = ref.read(authLoadingProvider.notifier);
    final snackbar = ref.read(snackbarServiceProvider);

    loading.state = true;
    try {
      await ref.read(authStateProvider.notifier).loginSecurity(
            phone: phone,
            password: password,
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

  Future<void> _submitEmployeePassword() async {
    final phone = _phoneController.text.trim();
    final password = _employeePasswordController.text.trim();
    final expected = PhoneUtils.lastSixDigits(phone);
    if (password.length != 6 || password != expected) {
      ref.read(snackbarServiceProvider).showError(
            'Enter the last 6 digits of this mobile number.',
          );
      return;
    }

    final loading = ref.read(authLoadingProvider.notifier);
    final snackbar = ref.read(snackbarServiceProvider);

    loading.state = true;
    try {
      await ref.read(authStateProvider.notifier).loginEmployee(
            phone: phone,
            password: password,
          );
      if (!mounted) return;
      await _completeAuthenticatedFlow();
    } on AppException catch (e) {
      snackbar.showError(e.message);
    } catch (_) {
      snackbar.showError('Employee sign-in failed. Please try again.');
    } finally {
      loading.state = false;
    }
  }

  Future<void> _sendOtp() async {
    final snackbar = ref.read(snackbarServiceProvider);
    final result = await ref
        .read(authStateProvider.notifier)
        .sendPhoneOtp(_phoneController.text.trim());

    ref.read(phoneAuthStepProvider.notifier).state = PhoneAuthStep.enterOtp;
    ref.read(verifiedPhoneProvider.notifier).state = result.phone;
    _otpController.clear();

    if (result.autoVerified) {
      await _verifyOtpAndContinue(autoVerified: true);
      return;
    }

    snackbar.showSuccess(
      result.message?.trim().isNotEmpty == true
          ? result.message!
          : 'OTP sent to ${_formattedPhone(result.phone)}',
    );
    _startResendCooldown();
  }

  Future<void> _resendOtp() async {
    if (_resendCooldownSeconds > 0) return;
    final snackbar = ref.read(snackbarServiceProvider);
    final loading = ref.read(authLoadingProvider.notifier);
    loading.state = true;
    try {
      _otpController.clear();
      final result = await ref
          .read(authStateProvider.notifier)
          .sendPhoneOtp(_phoneController.text.trim());
      ref.read(verifiedPhoneProvider.notifier).state = result.phone;
      if (result.autoVerified) {
        await _verifyOtpAndContinue(autoVerified: true);
        return;
      }
      snackbar.showSuccess(
        'A new OTP was sent to ${_formattedPhone(result.phone)}',
      );
      _startResendCooldown();
    } on AppException catch (e) {
      snackbar.showError(e.message);
    } catch (_) {
      snackbar.showError('Could not resend OTP. Please try again.');
    } finally {
      loading.state = false;
    }
  }

  Future<void> _verifyOtpAndContinue({bool autoVerified = false}) async {
    if (!autoVerified && _otpController.text.trim().length != 6) {
      ref.read(snackbarServiceProvider).showError('Enter the 6-digit OTP.');
      return;
    }

    final loading = ref.read(authLoadingProvider.notifier);
    final snackbar = ref.read(snackbarServiceProvider);
    final isSignUp = widget.mode == AuthFormMode.signUp;

    loading.state = true;
    try {
      await ref.read(authStateProvider.notifier).verifyPhoneOtp(
            phone: _phoneController.text.trim(),
            otp: _otpController.text.trim(),
            mode: widget.mode,
            displayName: isSignUp ? _nameController.text.trim() : null,
            role: isSignUp ? _signUpRole : null,
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

    final loading = ref.read(authLoadingProvider.notifier);
    final snackbar = ref.read(snackbarServiceProvider);
    final authNotifier = ref.read(authStateProvider.notifier);
    final isSignUp = widget.mode == AuthFormMode.signUp;

    loading.state = true;
    try {
      if (isSignUp) {
        await authNotifier.registerAccount(
          email: _emailController.text.trim(),
          password: _passwordController.text,
          displayName: _nameController.text.trim(),
          role: _signUpRole,
        );

        ref.read(pendingRegistrationProvider.notifier).state = null;
        ref.read(postAuthRoleSelectionProvider.notifier).state = false;
        _passwordController.clear();
        _nameController.clear();
        if (!mounted) return;
        context.go(RoutePaths.login);
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
        isSignUp
            ? 'Sign up failed. Please try again.'
            : 'Sign in failed. Please try again.',
      );
    } finally {
      loading.state = false;
    }
  }

  Future<void> _signInWithGoogle() async {
    final loading = ref.read(authLoadingProvider.notifier);
    final snackbar = ref.read(snackbarServiceProvider);
    final authNotifier = ref.read(authStateProvider.notifier);
    final isSignUp = widget.mode == AuthFormMode.signUp;

    if (isSignUp &&
        (_signUpRole == UserRole.admin || _signUpRole == UserRole.employee)) {
      snackbar.showError('Select Vehicle Owner or Land Owner.');
      return;
    }

    loading.state = true;
    try {
      if (isSignUp) {
        await authNotifier.signUpWithGoogle(role: _signUpRole);
      } else {
        await authNotifier.signInWithGoogle();
      }

      ref.read(pendingRegistrationProvider.notifier).state = null;
      await _completeAuthenticatedFlow();
    } on AppException catch (e) {
      snackbar.showError(e.message);
    } catch (e) {
      final msg = e.toString().toLowerCase();
      if (msg.contains('popup') || msg.contains('blocked')) {
        snackbar.showError(
          'Google popup was blocked. Allow popups for this site in your browser and try again.',
        );
      } else if (msg.contains('origin') ||
          msg.contains('client_id') ||
          msg.contains('idpiframe')) {
        snackbar.showError(
          'Google sign-in is not configured for this URL. '
          'Add localhost to authorized origins in Google Cloud Console.',
        );
      } else {
        snackbar.showError('Google sign-in failed. Please try again.');
      }
    } finally {
      if (mounted) loading.state = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final phoneStep = ref.watch(phoneAuthStepProvider);
    final isLoading = ref.watch(authLoadingProvider);
    final isSignUp = widget.mode == AuthFormMode.signUp;
    final colorScheme = Theme.of(context).colorScheme;

    return AuthScaffold(
      title: isSignUp ? 'Sign Up' : 'Sign In',
      style: AuthScaffoldStyle.form,
      subtitle: isSignUp
          ? 'Create an account to get started.'
          : 'Welcome back. Sign in to continue.',
      onBack: isLoading
          ? null
          : (_subview == _AuthSubview.picker ? _backToWelcome : _backToPicker),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
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
              Text(
                isSignUp ? 'Sign up with phone number' : 'Sign in with phone number',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                'Enter your mobile number to continue',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 20),
              if (phoneStep == PhoneAuthStep.enterPhone) ...[
                AppTextField(
                  controller: _phoneController,
                  label: 'Mobile Number',
                  hint: '10-digit mobile number',
                  keyboardType: TextInputType.phone,
                  prefixText: '+91 ',
                  validator: Validators.mobileNumber,
                ),
                if (_checkingAccountLabel != null) ...[
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        _checkingAccountLabel!,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 20),
                PrimaryButton(
                  label: 'Continue',
                  isLoading: isLoading,
                  onPressed: _continueWithPhone,
                ),
              ] else if (phoneStep == PhoneAuthStep.enterEmployeePassword) ...[
                Text(
                  'Employee Sign In',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  'Password is the last 6 digits of this mobile number.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Mobile Number',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                const SizedBox(height: 4),
                Text(
                  _formattedPhone(_phoneController.text.trim()),
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 16),
                AppPasswordField(
                  controller: _employeePasswordController,
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
                  label: 'Sign In',
                  isLoading: isLoading,
                  onPressed: _submitEmployeePassword,
                ),
              ] else if (phoneStep == PhoneAuthStep.enterSecurityPassword) ...[
                Text(
                  'Security Sign In',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  'Password is the last 4 digits of this mobile number.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Mobile Number',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                const SizedBox(height: 4),
                Text(
                  _formattedPhone(_phoneController.text.trim()),
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 16),
                AppPasswordField(
                  controller: _employeePasswordController,
                  label: 'Password (last 4 digits)',
                  validator: (value) {
                    if (value == null || value.trim().length != 4) {
                      return 'Enter the last 4 digits';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),
                PrimaryButton(
                  label: 'Sign In',
                  isLoading: isLoading,
                  onPressed: _submitSecurityPassword,
                ),
              ] else ...[
                Text(
                  'Verify Mobile Number',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  "We've sent a verification code to\n${_formattedPhone(_phoneController.text.trim())}",
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                ),
                const SizedBox(height: 16),
                AppTextField(
                  controller: _otpController,
                  label: 'OTP',
                  hint: '6-digit code',
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  validator: (value) {
                    if (phoneStep != PhoneAuthStep.enterOtp) return null;
                    if (value == null || value.trim().length != 6) {
                      return 'Enter the 6-digit OTP';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                PrimaryButton(
                  label: isSignUp ? 'Verify & Create Account' : 'Verify OTP',
                  isLoading: isLoading,
                  onPressed: _verifyOtpAndContinue,
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: isLoading || _resendCooldownSeconds > 0
                      ? null
                      : _resendOtp,
                  child: Text(
                    _resendCooldownSeconds > 0
                        ? 'Resend OTP in $_resendCooldownSeconds seconds'
                        : 'Resend OTP',
                  ),
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
          style: ButtonStyle(
            visualDensity: VisualDensity.compact,
            padding: const WidgetStatePropertyAll(
              EdgeInsets.symmetric(horizontal: 8, vertical: 10),
            ),
            textStyle: WidgetStatePropertyAll(
              Theme.of(context).textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
          showSelectedIcon: false,
          segments: const [
            ButtonSegment(
              value: UserRole.vehicleOwner,
              label: Text(
                'Vehicle Owner',
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.visible,
                textAlign: TextAlign.center,
              ),
            ),
            ButtonSegment(
              value: UserRole.landOwner,
              label: Text(
                'Land Owner',
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.visible,
                textAlign: TextAlign.center,
              ),
            ),
          ],
          selected: {selectedRole},
          onSelectionChanged: (selection) => onChanged(selection.first),
        ),
      ],
    );
  }
}
