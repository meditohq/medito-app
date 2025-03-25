import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medito/constants/constants.dart';
import 'package:medito/providers/favorites/favorites_provider.dart';
import 'package:medito/providers/me/me_provider.dart';
import 'package:medito/providers/stats_provider.dart';
import 'package:medito/repositories/auth/auth_repository.dart';
import 'package:medito/services/network/header_service.dart';
import 'package:medito/utils/stats_manager.dart';
import 'package:medito/views/settings/user_profile_page.dart';
import 'package:email_validator/email_validator.dart';
import 'package:medito/widgets/snackbar_widget.dart';
import 'package:medito/routes/routes.dart' as routes;
import 'package:flutter/gestures.dart';
import 'package:medito/views/onboarding/onboarding_pager_screen.dart';

import '../../providers/device_and_app_info/device_and_app_info_provider.dart';
import '../../providers/pack/pack_provider.dart';

class SignUpLogInPage extends ConsumerWidget {
  const SignUpLogInPage({
    super.key,
    this.fromSettings = false,
  });

  final bool fromSettings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authRepository = ref.watch(authRepositorySyncProvider);
    final user = authRepository.currentUser;

    if (user?.email != null && user?.email?.isNotEmpty == true) {
      return const UserProfilePage();
    } else {
      return SignUpLogInForm(fromSettings: fromSettings);
    }
  }
}

class SignUpLogInForm extends ConsumerStatefulWidget {
  const SignUpLogInForm({
    super.key,
    required this.fromSettings,
  });

  final bool fromSettings;

  @override
  ConsumerState<SignUpLogInForm> createState() => SignUpLogInFormState();
}

class SignUpLogInFormState extends ConsumerState<SignUpLogInForm> {
  final _emailController = TextEditingController();
  final _otpController = TextEditingController();
  var _isLoading = false;
  var _isEmailValid = false;
  var _isOtpValid = false;
  var _hasRequestedOtp = false;

  @override
  void initState() {
    super.initState();
    _emailController.addListener(_validateEmail);
    _otpController.addListener(_validateOtp);
  }

  @override
  void dispose() {
    _emailController.removeListener(_validateEmail);
    _otpController.removeListener(_validateOtp);
    _emailController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  void _validateEmail() {
    setState(() {
      _isEmailValid = EmailValidator.validate(_emailController.text.trim());
    });
  }

  void _validateOtp() {
    setState(() {
      _isOtpValid = _otpController.text.trim().length == 6;
    });
  }

  bool get _isFormValid =>
      _isEmailValid && (_hasRequestedOtp ? _isOtpValid : true);

  Future<void> _requestOtp() async {
    final hasLocalStats = await StatsManager().hasLocalStats();

    if (hasLocalStats) {
      final proceed = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              backgroundColor: ColorConstants.ebony,
              title: const Text(
                StringConstants.accountTransitionWarningTitle,
                style: TextStyle(color: Colors.white),
              ),
              content: Text(
                StringConstants.loginWarningExplanation,
                style: TextStyle(color: Colors.white70),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text(
                    StringConstants.cancelAction,
                    style: TextStyle(color: ColorConstants.brightSky),
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text(
                    StringConstants.continueLogin,
                    style: TextStyle(color: Colors.red),
                  ),
                ),
              ],
            ),
          ) ??
          false;

      if (!proceed) return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      await ref
          .read(authRepositorySyncProvider)
          .requestOtp(_emailController.text.trim());
      setState(() {
        _hasRequestedOtp = true;
      });
    } catch (e) {
      showSnackBar(context, 'Error: ${e.toString()}');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _verifyOtp() async {
    setState(() {
      _isLoading = true;
    });

    try {
      var success = await ref.read(authRepositorySyncProvider).verifyOtp(
            _emailController.text.trim(),
            _otpController.text.trim(),
          );

      if (success) {
        await _refreshUserInfo();
        await StatsManager().clearAllStats();
        ref.read(statsProvider.notifier).refresh();
        ref.invalidate(packProvider);

        // Initialize favorites after successful login
        unawaited(
            ref.read(favoritesNotifierProvider.notifier).syncWithServer());

        if (!mounted) return;

        if (widget.fromSettings) {
          Navigator.of(context).pop();
        } else {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(
              builder: (context) => const OnboardingPagerScreen(),
            ),
            (route) => false,
          );
        }
      } else {
        showSnackBar(context, 'Authentication failed');
      }
    } catch (e) {
      if (e.toString().contains('403')) {
        showSnackBar(context, 'Invalid verification code. Please try again.');
      } else {
        showSnackBar(context, 'Error: ${e.toString()}');
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _refreshUserInfo() async {
    // First invalidate the providers to clear their state
    ref.invalidate(meProvider);
    ref.invalidate(deviceAppAndUserInfoProvider);

    // Then initialize headers with device info
    final deviceInfo = await ref.read(deviceAndAppInfoProvider.future);
    await HeaderService(deviceInfo).initialise();
  }

  @override
  Widget build(BuildContext context) {
    const inputTextStyle = TextStyle(color: ColorConstants.onyx);

    return Scaffold(
      backgroundColor: ColorConstants.ebony,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: _hasRequestedOtp
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () {
                  setState(() {
                    _hasRequestedOtp = false;
                    _otpController.clear();
                  });
                },
              )
            : null,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            32.0,
            0,
            32.0,
            MediaQuery.of(context).viewInsets.bottom + 32.0,
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: MediaQuery.of(context).size.height -
                  MediaQuery.of(context).padding.top -
                  kToolbarHeight -
                  MediaQuery.of(context).viewInsets.bottom,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _hasRequestedOtp
                    ? _buildOtpVerificationView(inputTextStyle)
                    : _buildInitialView(inputTextStyle),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInitialView(TextStyle inputTextStyle) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _buildBenefitsText(StringConstants.createAccountBenefits),
        height64,
        Text(
          StringConstants.emailVerificationText,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            height: 1.5,
            fontWeight: FontWeight.normal,
          ),
        ),
        height16,
        _buildEmailField(inputTextStyle),
        height16,
        ElevatedButton(
          onPressed: (_isLoading || !_isFormValid) ? null : _requestOtp,
          style: _getButtonStyle(),
          child: _isLoading
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : const Text(StringConstants.sendMeMyPasswordText),
        ),
        _buildPrivacyPolicyLink(),
        SizedBox.square(
          dimension: 100,
        )
      ],
    );
  }

  Widget _buildOtpVerificationView(TextStyle inputTextStyle) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: '${StringConstants.otpInstructions}\n',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  height: 1.5,
                  fontWeight: FontWeight.normal,
                ),
              ),
              TextSpan(
                text: _emailController.text,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  height: 1.5,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          textAlign: TextAlign.center,
        ),
        height32,
        _buildOtpField(inputTextStyle),
        height16,
        ElevatedButton(
          onPressed: (_isLoading || !_isOtpValid) ? null : _verifyOtp,
          style: _getButtonStyle(),
          child: _isLoading
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : const Text(StringConstants.verifyOtpButtonText),
        ),
        height16,
        TextButton(
          onPressed: _isLoading ? null : _requestOtp,
          style: TextButton.styleFrom(
            padding: EdgeInsets.zero,
            minimumSize: const Size(0, 32),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: Text(
            StringConstants.resendCode,
            style: TextStyle(
              color: _isLoading ? Colors.white38 : ColorConstants.brightSky,
              fontSize: 14,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmailField(TextStyle inputTextStyle) {
    return TextField(
      controller: _emailController,
      enabled: !_hasRequestedOtp,
      decoration: getInputDecoration(
        StringConstants.emailLabel,
        _isEmailValid || _emailController.text.isEmpty,
        StringConstants.invalidEmailError,
      ).copyWith(
        fillColor: Colors.white,
        filled: true,
        suffixIcon: _emailController.text.isNotEmpty && !_hasRequestedOtp
            ? IconButton(
                icon: const Icon(Icons.clear, color: Colors.white60),
                onPressed: () {
                  _emailController.clear();
                  _validateEmail();
                },
              )
            : null,
      ),
      onChanged: (_) => setState(() {}),
      style: const TextStyle(color: ColorConstants.onyx),
      keyboardType: TextInputType.emailAddress,
    );
  }

  Widget _buildOtpField(TextStyle inputTextStyle) {
    return TextField(
      controller: _otpController,
      decoration: getInputDecoration(
        StringConstants.otpLabel,
        _isOtpValid || _otpController.text.isEmpty,
        StringConstants.invalidOtpError,
      ).copyWith(
        fillColor: Colors.white,
        filled: true,
      ),
      style: const TextStyle(color: ColorConstants.onyx),
      keyboardType: TextInputType.number,
      maxLength: 6,
    );
  }

  Widget _buildPrivacyPolicyLink() {
    return Padding(
      padding: const EdgeInsets.only(top: 16.0),
      child: Center(
        child: Text.rich(
          TextSpan(
            text: 'By continuing, you agree to our ',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
            ),
            children: [
              TextSpan(
                text: 'Terms of Service',
                style: const TextStyle(
                  color: ColorConstants.brightSky,
                  decoration: TextDecoration.underline,
                ),
                recognizer: TapGestureRecognizer()
                  ..onTap = () => routes.handleNavigation(
                        TypeConstants.url,
                        ['https://meditofoundation.org/terms'],
                        context,
                        ref: ref,
                      ),
              ),
              const TextSpan(text: ' and '),
              TextSpan(
                text: 'Privacy Policy',
                style: const TextStyle(
                  color: ColorConstants.brightSky,
                  decoration: TextDecoration.underline,
                ),
                recognizer: TapGestureRecognizer()
                  ..onTap = () => routes.handleNavigation(
                        TypeConstants.url,
                        ['https://meditofoundation.org/privacy'],
                        context,
                        ref: ref,
                      ),
              ),
            ],
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  ButtonStyle _getButtonStyle() {
    return ElevatedButton.styleFrom(
      foregroundColor: ColorConstants.onyx,
      backgroundColor: ColorConstants.lightPurple,
      disabledForegroundColor: Colors.white60,
      disabledBackgroundColor: ColorConstants.lightPurple.withOpacity(0.5),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(4),
      ),
      minimumSize: const Size(double.infinity, 48),
    );
  }

  InputDecoration getInputDecoration(
      String hint, bool isValid, String? errorText) {
    const borderRadius = BorderRadius.all(Radius.circular(4));

    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Colors.black38),
      filled: true,
      fillColor: Colors.white,
      enabledBorder: const OutlineInputBorder(
        borderRadius: borderRadius,
        borderSide: BorderSide(color: ColorConstants.softGrey),
      ),
      focusedBorder: const OutlineInputBorder(
        borderRadius: borderRadius,
        borderSide: BorderSide(color: ColorConstants.lightPurple),
      ),
      disabledBorder: const OutlineInputBorder(
        borderRadius: borderRadius,
        borderSide: BorderSide(color: ColorConstants.softGrey),
      ),
      errorBorder: const OutlineInputBorder(
        borderRadius: borderRadius,
        borderSide: BorderSide(color: Colors.red),
      ),
      focusedErrorBorder: const OutlineInputBorder(
        borderRadius: borderRadius,
        borderSide: BorderSide(color: Colors.red),
      ),
      errorText: !isValid && errorText != null ? errorText : null,
      errorStyle: const TextStyle(color: Colors.red),
    );
  }

  Widget _buildBenefitsText(String text) {
    return Text(
      text,
      textAlign: TextAlign.start,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 20,
        height: 1.5,
        fontWeight: FontWeight.w500,
      ),
    );
  }
}
