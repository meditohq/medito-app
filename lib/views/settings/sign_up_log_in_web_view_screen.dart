import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medito/constants/constants.dart';
import 'package:medito/providers/stats_provider.dart';
import 'package:medito/repositories/auth/auth_repository.dart';
import 'package:medito/views/settings/user_profile_page.dart';
import 'package:email_validator/email_validator.dart';
import 'package:medito/views/player/widgets/bottom_actions/single_back_action_bar.dart';
import 'package:medito/widgets/headers/medito_app_bar_small.dart';
import 'package:medito/widgets/snackbar_widget.dart';
import 'package:medito/routes/routes.dart' as routes;

import '../../providers/device_and_app_info/device_and_app_info_provider.dart';

class SignUpLogInPage extends ConsumerWidget {
  const SignUpLogInPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authRepository = ref.watch(authRepositoryProvider);
    final user = authRepository.currentUser;

    if (user?.email != null && user?.email?.isNotEmpty == true) {
      return const UserProfilePage();
    } else {
      return const SignUpLogInForm();
    }
  }
}

class SignUpLogInForm extends ConsumerStatefulWidget {
  const SignUpLogInForm({super.key});

  @override
  ConsumerState<SignUpLogInForm> createState() => SignUpLogInFormState();
}

class SignUpLogInFormState extends ConsumerState<SignUpLogInForm> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  var _isLoading = false;
  var _isEmailValid = false;
  var _isPasswordValid = false;

  @override
  void initState() {
    super.initState();
    _emailController.addListener(_validateEmail);
    _passwordController.addListener(_validatePassword);
  }

  @override
  void dispose() {
    _emailController.removeListener(_validateEmail);
    _passwordController.removeListener(_validatePassword);
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _validateEmail() {
    setState(() {
      _isEmailValid = EmailValidator.validate(_emailController.text.trim());
    });
  }

  void _validatePassword() {
    setState(() {
      _isPasswordValid = _passwordController.text.trim().length >= 6;
    });
  }

  bool get _isFormValid => _isEmailValid && _isPasswordValid;

  Future<void> _signUp() async {
    await _performAuthAction(() => ref
        .read(authRepositoryProvider)
        .signUp(_emailController.text.trim(), _passwordController.text.trim()));
  }

  Future<void> _logIn() async {
    final authRepository = ref.read(authRepositoryProvider);
    if (authRepository.currentUser?.email == null) {
      final action = await _showAccountTransitionWarningDialog();
      if (action == AccountAction.cancel) return;
      if (action == AccountAction.createAccount) {
        await _signUp();
        return;
      }
    } else {
      final shouldProceed = await _showLoginDialog();
      if (!shouldProceed) return;
    }

    try {
      await _performAuthAction(() => authRepository.logIn(
          _emailController.text.trim(), _passwordController.text.trim()));
    } on AuthError catch (e) {
      switch (e.type) {
        case AuthException.accountMarkedForDeletion:
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text(StringConstants.accountMarkedForDeletionError)),
          );
          break;
        case AuthException.other:
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: ${e.message}')),
          );
          break;
      }
    }
  }

  Future<bool> _showLoginDialog() async {
    return await showDialog<bool>(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text(StringConstants.accountTransitionWarningTitle),
              content: const Text(StringConstants.loginWarningMessage),
              actions: <Widget>[
                TextButton(
                  child: const Text(StringConstants.cancelAction),
                  onPressed: () => Navigator.of(context).pop(false),
                ),
                TextButton(
                  child: const Text(StringConstants.continueLogin),
                  onPressed: () => Navigator.of(context).pop(true),
                ),
              ],
            );
          },
        ) ??
        false;
  }

  Future<AccountAction> _showAccountTransitionWarningDialog() async {
    return await showDialog<AccountAction>(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text(StringConstants.accountTransitionWarningTitle),
              content: const Text(StringConstants.loginWarningMessage),
              actions: <Widget>[
                TextButton(
                  child: const Text(StringConstants.cancelAction),
                  onPressed: () =>
                      Navigator.of(context).pop(AccountAction.cancel),
                ),
                TextButton(
                  child: const Text(StringConstants.createNewAccount),
                  onPressed: () =>
                      Navigator.of(context).pop(AccountAction.createAccount),
                ),
                TextButton(
                  child: const Text(StringConstants.continueLogin),
                  onPressed: () =>
                      Navigator.of(context).pop(AccountAction.login),
                ),
              ],
            );
          },
        ) ??
        AccountAction.cancel;
  }

  Future<void> _performAuthAction(Future<bool> Function() authAction) async {
    setState(() {
      _isLoading = true;
    });

    try {
      var success = await authAction();
      if (success) {
        await _refreshUserInfo();
        ref.invalidate(statsProvider);

        showSnackBar(context, StringConstants.signInSuccess);
        
        Navigator.of(context).pop(true);
      } else {
        showSnackBar(context, 'Authentication failed');
      }
    } catch (e) {
      showSnackBar(context, 'Error: ${e.toString()}');
    } finally {
      ref.invalidate(statsProvider);
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _refreshUserInfo() async {
    ref.invalidate(deviceAppAndUserInfoProvider);
  }

  @override
  Widget build(BuildContext context) {
    const inputTextStyle = TextStyle(color: ColorConstants.onyx);

    InputDecoration getInputDecoration(
        String hint, bool isValid, String? errorText) {
      return InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.black54),
        filled: true,
        fillColor: Colors.white,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Colors.white),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: ColorConstants.onyx),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Colors.red),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Colors.red),
        ),
        errorText: !isValid && errorText != null ? errorText : null,
        errorStyle: const TextStyle(color: Colors.red),
      );
    }

    return Scaffold(
      backgroundColor: ColorConstants.onyx,
      appBar: const MeditoAppBarSmall(
        title: StringConstants.signUpLogInTitle,
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: IntrinsicHeight(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        StringConstants.createAccountBenefits,
                        style: TextStyle(color: Colors.white),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        StringConstants.loginBenefits,
                        style: TextStyle(color: Colors.white),
                      ),
                      const SizedBox(height: 24),
                      TextField(
                        controller: _emailController,
                        decoration: getInputDecoration(
                          StringConstants.emailLabel,
                          _isEmailValid || _emailController.text.isEmpty,
                          StringConstants.invalidEmailError,
                        ),
                        style: inputTextStyle,
                        keyboardType: TextInputType.emailAddress,
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _passwordController,
                        decoration: getInputDecoration(
                          StringConstants.passwordLabel,
                          _isPasswordValid || _passwordController.text.isEmpty,
                          StringConstants.invalidPasswordError,
                        ),
                        style: inputTextStyle,
                        obscureText: true,
                      ),
                      height32,
                      ElevatedButton(
                        onPressed:
                            (_isLoading || !_isFormValid) ? null : _signUp,
                        style: ElevatedButton.styleFrom(
                          foregroundColor: ColorConstants.onyx,
                          backgroundColor: ColorConstants.brightSky,
                          disabledForegroundColor: Colors.grey,
                          disabledBackgroundColor: Colors.grey[300],
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          minimumSize: const Size(double.infinity, 48),
                        ),
                        child:
                            const Text(StringConstants.createAccountButtonText),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed:
                            (_isLoading || !_isFormValid) ? null : _logIn,
                        style: ElevatedButton.styleFrom(
                          foregroundColor: ColorConstants.onyx,
                          backgroundColor: ColorConstants.brightSky,
                          disabledForegroundColor: Colors.grey,
                          disabledBackgroundColor: Colors.grey[300],
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          minimumSize: const Size(double.infinity, 48),
                        ),
                        child: const Text(StringConstants.logInButtonText),
                      ),
                      if (_isLoading)
                        const Padding(
                          padding: EdgeInsets.only(top: 16.0),
                          child: CircularProgressIndicator(
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        ),
                      const SizedBox(height: 16),
                      Center(
                        child: GestureDetector(
                          onTap: _launchPrivacyPolicy,
                          child: const Text(
                            StringConstants.privacyPolicyTitle,
                            style: TextStyle(
                              color: ColorConstants.brightSky,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
      bottomNavigationBar: SingleBackButtonActionBar(
        onBackPressed: () => Navigator.of(context).pop(),
      ),
    );
  }

  void _launchPrivacyPolicy() {
    routes.handleNavigation(
      TypeConstants.url,
      ['https://meditofoundation.org/privacy'],
      context,
      ref: ref,
    );
  }
}

enum AccountAction {
  cancel,
  createAccount,
  login,
}
