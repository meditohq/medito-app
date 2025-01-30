import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medito/constants/constants.dart';
import 'package:medito/providers/me/me_provider.dart';
import 'package:medito/providers/stats_provider.dart';
import 'package:medito/repositories/auth/auth_repository.dart';
import 'package:medito/utils/stats_manager.dart';
import 'package:medito/views/settings/user_profile_page.dart';
import 'package:email_validator/email_validator.dart';
import 'package:medito/views/player/widgets/bottom_actions/single_back_action_bar.dart';
import 'package:medito/widgets/snackbar_widget.dart';
import 'package:medito/routes/routes.dart' as routes;
import 'package:flutter/gestures.dart';
import 'package:medito/models/account_action.dart';

import '../../providers/device_and_app_info/device_and_app_info_provider.dart';
import '../../providers/pack/pack_provider.dart';

class SignUpLogInPage extends ConsumerWidget {
  final int initialTabIndex;

  const SignUpLogInPage({super.key, this.initialTabIndex = 0});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authRepository = ref.watch(authRepositoryProvider);
    final user = authRepository.currentUser;

    if (user?.email != null && user?.email?.isNotEmpty == true) {
      return const UserProfilePage();
    } else {
      return SignUpLogInForm(initialTabIndex: initialTabIndex);
    }
  }
}

class SignUpLogInForm extends ConsumerStatefulWidget {
  final int initialTabIndex;

  const SignUpLogInForm({super.key, this.initialTabIndex = 0});

  @override
  ConsumerState<SignUpLogInForm> createState() => SignUpLogInFormState();
}

class SignUpLogInFormState extends ConsumerState<SignUpLogInForm>
    with SingleTickerProviderStateMixin {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  late TabController _tabController;
  var _isLoading = false;
  var _isEmailValid = false;
  var _isPasswordValid = false;
  var _isPasswordVisible = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTabIndex,
    );
    _emailController.addListener(_validateEmail);
    _passwordController.addListener(_validatePassword);
  }

  @override
  void dispose() {
    _tabController.dispose();
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
    await _performAuthAction(
      () => ref.read(authRepositoryProvider).signUp(
            _emailController.text.trim(),
            _passwordController.text.trim(),
          ),
      false,
    );
  }

  Future<void> _logIn() async {
    final stats = ref.read(statsProvider).valueOrNull;
    final hasCompletedAudio = stats?.audioCompleted?.isNotEmpty ?? false;

    if (hasCompletedAudio) {
      final action = await _showAccountTransitionWarningDialog();
      switch (action) {
        case AccountActionCancel():
          return;
        case AccountActionCreateAccount():
          await _signUp();
          return;
        case AccountActionLogin():
          break;
      }
    }

    try {
      await _performAuthAction(
        () => ref.read(authRepositoryProvider).logIn(
              _emailController.text.trim(),
              _passwordController.text.trim(),
            ),
        true,
      );
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
                      Navigator.of(context).pop(const AccountActionCancel()),
                ),
                TextButton(
                  child: const Text(StringConstants.createNewAccount),
                  onPressed: () => Navigator.of(context)
                      .pop(const AccountActionCreateAccount()),
                ),
                TextButton(
                  child: const Text(StringConstants.continueLogin),
                  onPressed: () =>
                      Navigator.of(context).pop(const AccountActionLogin()),
                ),
              ],
            );
          },
        ) ??
        const AccountActionCancel();
  }

  Future<void> _performAuthAction(
      Future<bool> Function() authAction, bool shouldClearStats) async {
    setState(() {
      _isLoading = true;
    });

    try {
      var success = await authAction();
      if (success) {
        await _refreshUserInfo();

        if (shouldClearStats) {
          await StatsManager().clearAllStats();
          ref.read(statsProvider.notifier).refresh();
          ref.invalidate(packProvider);
        }

        if (!mounted) return;
        showSnackBar(context, StringConstants.signInSuccess);
        ref.invalidate(meProvider);

        // Pop back to splash screen which will handle initialization
        Navigator.of(context).pop(true);
      } else {
        showSnackBar(context, 'Authentication failed');
      }
    } catch (e) {
      showSnackBar(context, 'Error: ${e.toString()}');
    } finally {
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

    return Scaffold(
      backgroundColor: ColorConstants.ebony,
      body: SafeArea(
        child: Column(
          children: [
            Container(
              decoration: const BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: ColorConstants.softGrey,
                    width: 1,
                  ),
                ),
              ),
              child: TabBar(
                controller: _tabController,
                tabs: const [
                  Tab(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Text(
                        StringConstants.createAccountButtonText,
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w500),
                      ),
                    ),
                  ),
                  Tab(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Text(
                        StringConstants.logInButtonText,
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w500),
                      ),
                    ),
                  ),
                ],
                labelColor: ColorConstants.lightPurple,
                unselectedLabelColor: Colors.white60,
                indicatorColor: ColorConstants.lightPurple,
                indicatorWeight: 4,
                indicatorSize: TabBarIndicatorSize.tab,
              ),
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildSignUpTab(inputTextStyle),
                  _buildLoginTab(inputTextStyle),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SingleBackButtonActionBar(
        onBackPressed: () => Navigator.of(context).pop(),
      ),
    );
  }

  Widget _buildLoginTab(TextStyle inputTextStyle) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildBenefitsText(StringConstants.loginBenefits),
          height32,
          _buildEmailField(inputTextStyle),
          const SizedBox(height: 16),
          _buildPasswordField(inputTextStyle),
          height32,
          ElevatedButton(
            onPressed: (_isLoading || !_isFormValid) ? null : _logIn,
            style: _getButtonStyle(),
            child: const Text(StringConstants.logInButtonText),
          ),
          _buildLoadingIndicator(),
          _buildPrivacyPolicyLink(),
        ],
      ),
    );
  }

  Widget _buildSignUpTab(TextStyle inputTextStyle) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildBenefitsText(StringConstants.createAccountBenefits),
          height32,
          _buildEmailField(inputTextStyle),
          const SizedBox(height: 16),
          _buildPasswordField(inputTextStyle),
          height32,
          ElevatedButton(
            onPressed: (_isLoading || !_isFormValid) ? null : _signUp,
            style: _getButtonStyle(),
            child: const Text(StringConstants.createAccountButtonText),
          ),
          _buildLoadingIndicator(),
          _buildPrivacyPolicyLink(),
        ],
      ),
    );
  }

  Widget _buildEmailField(TextStyle inputTextStyle) {
    return TextField(
      controller: _emailController,
      decoration: getInputDecoration(
        StringConstants.emailLabel,
        _isEmailValid || _emailController.text.isEmpty,
        StringConstants.invalidEmailError,
      ).copyWith(
        suffixIcon: _emailController.text.isNotEmpty
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
      style: const TextStyle(color: Colors.white),
      keyboardType: TextInputType.emailAddress,
    );
  }

  Widget _buildPasswordField(TextStyle inputTextStyle) {
    return TextField(
      controller: _passwordController,
      decoration: getInputDecoration(
        StringConstants.passwordLabel,
        _isPasswordValid || _passwordController.text.isEmpty,
        StringConstants.invalidPasswordError,
      ).copyWith(
        suffixIcon: IconButton(
          icon: Icon(
            _isPasswordVisible ? Icons.visibility : Icons.visibility_off,
            color: Colors.white60,
          ),
          onPressed: () {
            setState(() {
              _isPasswordVisible = !_isPasswordVisible;
            });
          },
        ),
      ),
      style: const TextStyle(color: Colors.white),
      obscureText: !_isPasswordVisible,
    );
  }

  Widget _buildLoadingIndicator() {
    if (!_isLoading) return const SizedBox.shrink();

    return const Padding(
      padding: EdgeInsets.only(top: 16.0),
      child: CircularProgressIndicator(
        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
      ),
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
        borderRadius: BorderRadius.circular(8),
      ),
      minimumSize: const Size(double.infinity, 48),
    );
  }

  InputDecoration getInputDecoration(
      String hint, bool isValid, String? errorText) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Colors.white60),
      filled: true,
      fillColor: ColorConstants.onyx,
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: ColorConstants.softGrey),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: ColorConstants.lightPurple),
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

  Widget _buildBenefitsText(String text) {
    return Text(
      text,
      textAlign: TextAlign.center,
      style: const TextStyle(
        color: Colors.white70,
        fontSize: 18,
        height: 1.5,
      ),
    );
  }
}
