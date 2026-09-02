// ignore_for_file: use_build_context_synchronously

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medito/constants/constants.dart';
import 'package:medito/exceptions/app_error.dart';
import 'package:medito/l10n/app_localizations.dart';
import 'package:medito/providers/favorites/favorites_provider.dart';
import 'package:medito/providers/me/me_provider.dart';
import 'package:medito/providers/stats_provider.dart';
import 'package:medito/repositories/auth/auth_repository.dart';
import 'package:medito/services/analytics/crashlytics_service.dart';
import 'package:medito/services/analytics/firebase_analytics_service.dart';
import 'package:medito/services/analytics/meta_sdk_service.dart';
import 'package:medito/services/network/header_service.dart';
import 'package:medito/utils/logger.dart';
import 'package:email_validator/email_validator.dart';
import 'package:medito/widgets/dialogs/dialogs.dart';
import 'package:medito/widgets/snackbar_widget.dart';
import 'package:medito/utils/utils.dart';
import 'package:medito/routes/routes.dart' as routes;
import 'package:flutter/gestures.dart';
import 'package:medito/views/onboarding/onboarding_pager_screen.dart';
import 'package:app_links/app_links.dart';

import '../../providers/device_and_app_info/device_and_app_info_provider.dart';
import '../../providers/pack/pack_provider.dart';

final dev = const AppLoggerAdapter('SIGN_UP');

class SignUpLogInPage extends ConsumerWidget {
  const SignUpLogInPage({super.key, this.fromSettings = false});

  final bool fromSettings;
  static const routeName = '/signup';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authRepository = ref.watch(authRepositorySyncProvider);
    final user = authRepository.currentUser;

    dev.log('[SIGN_UP] Building SignUpLogInPage', level: 1000);
    dev.log('[SIGN_UP] Current user: $user', level: 1000);
    dev.log('[SIGN_UP] User email: ${user?.email}', level: 1000);

    if (user?.email != null && user?.email?.isNotEmpty == true) {
      dev.log(
        '[SIGN_UP] User has email, navigating back or to home',
        level: 1000,
      );
      // If opened from settings and user is already logged in, just pop.
      // Otherwise, this case might not be reachable if auth guards are in place before this screen.
      // However, to be safe, popping is a sensible default.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (Navigator.canPop(context)) {
          Navigator.pop(context);
        }
      });
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: Center(
          child: CircularProgressIndicator(color: context.brandPurple),
        ),
      ); // Show loading while popping
    } else {
      dev.log('[SIGN_UP] User has no email, showing sign-up form', level: 1000);
      return SignUpLogInForm(fromSettings: fromSettings);
    }
  }
}

class SignUpLogInForm extends ConsumerStatefulWidget {
  const SignUpLogInForm({super.key, required this.fromSettings});

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
  var _isRateLimited = false;
  var _retryAfterSeconds = 0;
  Timer? _timer;
  StreamSubscription? _linkSubscription;
  final _appLinks = AppLinks();

  @override
  void initState() {
    super.initState();
    _emailController.addListener(_validateEmail);
    _otpController.addListener(_validateOtp);
    _setupDeepLinkHandling();
  }

  void _setupDeepLinkHandling() {
    _linkSubscription = _appLinks.uriLinkStream.listen((uri) {
      if (!mounted) return;

      if (uri.path.startsWith('/otp/')) {
        final otp = uri.pathSegments[1];
        if (otp.length == 6) {
          if (!mounted) return;

          if (!_hasRequestedOtp) {
            showSnackBar(
              context,
              AppLocalizations.of(context)!.requestOtpBeforeDeepLink,
            );
            return;
          }

          setState(() {
            _otpController.text = otp;
            _verifyOtp();
          });
        }
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _linkSubscription?.cancel();
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
    if (_isLoading || _isRateLimited) return;

    final hasLocalStats = await ref.read(statsManagerProvider).hasLocalStats();

    if (hasLocalStats) {
      final proceed =
          await showDialog<bool>(
            context: context,
            builder: (context) => MeditoDialog(
              title: AppLocalizations.of(
                context,
              )!.accountTransitionWarningTitle,
              content: MeditoDialogBody(
                AppLocalizations.of(context)!.loginWarningExplanation,
              ),
              actions: [
                MeditoDialogSecondaryButton(
                  label: AppLocalizations.of(context)!.cancelAction,
                  onPressed: () => Navigator.of(context).pop(false),
                ),
                MeditoDialogDestructiveButton(
                  label: AppLocalizations.of(context)!.continueLogin,
                  onPressed: () => Navigator.of(context).pop(true),
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
          .requestOtp(_emailController.text.trim().toLowerCase());
      setState(() {
        _hasRequestedOtp = true;
      });
    } on RateLimitError catch (e) {
      showSnackBar(context, e.message);
      setState(() {
        _isRateLimited = true;
        _retryAfterSeconds = e.tryAfterSeconds ?? 60;
      });
      _startRetryTimer();
    } on InactiveEmailError {
      showSnackBar(context, AppLocalizations.of(context)!.accountInactiveError);
    } on EmailMismatchError catch (e) {
      // Device is linked to a different email; surface the server's message
      // instead of silently creating a new account.
      showSnackBar(context, e.message);
    } catch (e) {
      showSnackBar(
        context,
        '${AppLocalizations.of(context)!.errorPrefix}${e.toString()}',
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _startRetryTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_retryAfterSeconds > 0) {
        setState(() {
          _retryAfterSeconds--;
        });
      } else {
        timer.cancel();
        setState(() {
          _isRateLimited = false;
        });
      }
    });
  }

  Future<void> _verifyOtp() async {
    setState(() {
      _isLoading = true;
    });

    try {
      dev.log('[SIGN_UP] Starting OTP verification', level: 1000);
      dev.log('[SIGN_UP] Email: ${_emailController.text.trim()}', level: 1000);
      dev.log(
        '[SIGN_UP] OTP length: ${_otpController.text.trim().length}',
        level: 1000,
      );

      // Remember which account this device was on, so we only wipe local
      // stats when the server actually switches us to a different one.
      final previousUserId = ref.read(userIdProvider);

      var success = await ref
          .read(authRepositorySyncProvider)
          .verifyOtp(
            _emailController.text.trim().toLowerCase(),
            _otpController.text.trim(),
          );

      dev.log('[SIGN_UP] OTP verification result: $success', level: 1000);

      if (success) {
        dev.log(
          '[SIGN_UP] OTP verification successful, refreshing user info',
          level: 1000,
        );
        await _refreshUserInfo();

        // Log the state of the auth repository after successful login
        final authRepo = ref.read(authRepositorySyncProvider);
        dev.log(
          '[SIGN_UP] User after successful login: ${authRepo.currentUser}',
          level: 1000,
        );
        dev.log(
          '[SIGN_UP] User email after login: ${authRepo.getUserEmail()}',
          level: 1000,
        );

        // Set user ID for analytics immediately after successful sign-in
        // This ensures user ID is set before any events are logged
        try {
          final userId = ref.read(userIdProvider);
          if (userId != null && userId.isNotEmpty) {
            await FirebaseAnalyticsService().setUserId(userId);
            await MetaSdkService.instance.setUserId(userId);
            dev.log(
              '[SIGN_UP] User ID set for analytics: $userId',
              level: 1000,
            );
          }
        } catch (e) {
          dev.log(
            '[SIGN_UP] Error setting user ID for analytics: $e',
            level: 1000,
          );
        }

        // Log analytics event for completed signup
        await FirebaseAnalyticsService().logEvent(
          name: FirebaseAnalyticsService.eventOnboardingSignupCompleted,
        );

        // Initialize first — clearAllStats touches SharedPreferences and
        // will throw LateInitializationError if the singleton hasn't been
        // initialized yet (e.g. user signs in straight from onboarding
        // without ever loading the home screen).
        final statsManager = ref.read(statsManagerProvider);
        await statsManager.initialize();
        final newUserId = ref.read(userIdProvider);
        if (newUserId != previousUserId) {
          // Server moved us onto a different account: drop the local copy of
          // the old one before pulling the new account's stats.
          await statsManager.clearAllStats();
        }
        // Force sync to fetch the (possibly different) account's stats
        await statsManager.sync(force: true);
        ref.read(statsProvider.notifier).refresh();
        ref.invalidate(packProvider);

        // Initialize favorites after successful login
        unawaited(
          ref.read(favoritesNotifierProvider.notifier).syncWithServer(),
        );

        if (!mounted) return;

        dev.log(
          '[SIGN_UP] Login complete, navigating to next screen',
          level: 1000,
        );
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
        showSnackBar(
          context,
          AppLocalizations.of(context)!.authenticationFailed,
        );
      }
    } catch (e, st) {
      dev.log('[SIGN_UP] Error during OTP verification', error: e, level: 1000);
      if (e.toString().contains('403')) {
        showSnackBar(
          context,
          AppLocalizations.of(context)!.invalidVerificationCode,
        );
      } else {
        CrashlyticsService().recordError(
          e,
          st,
          reason: 'OTP verify post-success',
        );
        showSnackBar(
          context,
          '${AppLocalizations.of(context)!.errorPrefix}${e.toString()}',
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _refreshUserInfo() async {
    dev.log('[SIGN_UP] Starting user info refresh', level: 1000);

    // First invalidate the providers to clear their state
    ref.invalidate(meProvider);
    ref.invalidate(deviceAppAndUserInfoProvider);

    // Log current auth state before header initialization
    final authRepo = ref.read(authRepositorySyncProvider);
    dev.log(
      '[SIGN_UP] Auth state before header init: ${authRepo.currentUser}',
      level: 1000,
    );

    // Then initialize headers with device info (which now includes user's language preference)
    final deviceInfo = await ref.read(deviceAndAppInfoProvider.future);
    await HeaderService(deviceInfo).initialise();

    dev.log(
      '[SIGN_UP] Headers initialized, auth state after: ${authRepo.currentUser}',
      level: 1000,
    );
  }

  @override
  Widget build(BuildContext context) {
    final inputTextStyle = TextStyle(
      color: Theme.of(context).colorScheme.onSurface,
    );

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
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
              minHeight:
                  MediaQuery.of(context).size.height -
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
        _buildBenefitsText(AppLocalizations.of(context)!.createAccountBenefits),
        height64,
        Text(
          AppLocalizations.of(context)!.emailVerificationText,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            fontSize: 13,
            height: 1.5,
            fontWeight: FontWeight.normal,
          ),
        ),
        height16,
        _buildEmailField(inputTextStyle),
        height16,
        ElevatedButton(
          onPressed: (_isLoading || !_isFormValid || _isRateLimited)
              ? null
              : _requestOtp,
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
              : _isRateLimited
              ? Text(
                  AppLocalizations.of(
                    context,
                  )!.retryInSeconds(_retryAfterSeconds.toString()),
                )
              : Text(AppLocalizations.of(context)!.sendMeMyPasswordText),
        ),
        _buildPrivacyPolicyLink(),
        SizedBox.square(dimension: 100),
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
                text: '${AppLocalizations.of(context)!.otpInstructions}\n',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontSize: 18,
                  height: 1.5,
                  fontWeight: FontWeight.normal,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              TextSpan(
                text: _emailController.text,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontSize: 18,
                  height: 1.5,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
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
              : Text(AppLocalizations.of(context)!.verifyOtpButtonText),
        ),
        height16,
        TextButton(
          onPressed: _isLoading || _isRateLimited ? null : _requestOtp,
          style: TextButton.styleFrom(
            padding: EdgeInsets.zero,
            minimumSize: const Size(0, 32),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: Text(
            _isRateLimited
                ? AppLocalizations.of(
                    context,
                  )!.resendCodeInSeconds(_retryAfterSeconds.toString())
                : AppLocalizations.of(context)!.resendCode,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: _isLoading || _isRateLimited
                  ? Theme.of(
                      context,
                    ).textTheme.bodySmall?.color?.withOpacityValue(0.38)
                  : ColorConstants.brightSky,
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
      decoration:
          getInputDecoration(
            AppLocalizations.of(context)!.emailLabel,
            _isEmailValid || _emailController.text.isEmpty,
            AppLocalizations.of(context)!.invalidEmailError,
          ).copyWith(
            fillColor: Theme.of(context).colorScheme.surface,
            filled: true,
            suffixIcon: _emailController.text.isNotEmpty && !_hasRequestedOtp
                ? IconButton(
                    icon: Icon(
                      Icons.clear,
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withOpacityValue(0.6),
                    ),
                    onPressed: () {
                      _emailController.clear();
                      _validateEmail();
                    },
                  )
                : null,
          ),
      onChanged: (_) => setState(() {}),
      style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
      keyboardType: TextInputType.emailAddress,
      inputFormatters: [
        TextInputFormatter.withFunction(
          (oldValue, newValue) => TextEditingValue(
            text: newValue.text.toLowerCase(),
            selection: newValue.selection,
          ),
        ),
      ],
    );
  }

  Widget _buildOtpField(TextStyle inputTextStyle) {
    return TextField(
      controller: _otpController,
      decoration:
          getInputDecoration(
            AppLocalizations.of(context)!.otpLabel,
            _isOtpValid || _otpController.text.isEmpty,
            AppLocalizations.of(context)!.invalidOtpError,
          ).copyWith(
            fillColor: Theme.of(context).colorScheme.surface,
            filled: true,
          ),
      style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
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
            text: AppLocalizations.of(context)!.byContinuingAgreeTo,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(
                context,
              ).textTheme.bodySmall?.color?.withOpacityValue(0.7),
              fontSize: 12,
            ),
            children: [
              TextSpan(
                text: 'Terms of Service',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
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
              TextSpan(text: AppLocalizations.of(context)!.andText),
              TextSpan(
                text: 'Privacy Policy',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
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
      foregroundColor: Theme.of(context).colorScheme.onPrimary,
      backgroundColor: context.brandPurple,
      disabledForegroundColor: Colors.white60,
      disabledBackgroundColor: context.brandPurple.withOpacityValue(0.5),
      minimumSize: const Size(double.infinity, 48),
    );
  }

  InputDecoration getInputDecoration(
    String hint,
    bool isValid,
    String? errorText,
  ) {
    const borderRadius = BorderRadius.all(Radius.circular(4));

    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(
        color: Theme.of(context).colorScheme.onSurface.withOpacityValue(0.6),
      ),
      filled: true,
      fillColor: Theme.of(context).colorScheme.surface,
      enabledBorder: const OutlineInputBorder(
        borderRadius: borderRadius,
        borderSide: BorderSide(color: ColorConstants.softGrey),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: borderRadius,
        borderSide: BorderSide(color: context.brandPurple),
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
      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
        fontSize: 20,
        height: 1.5,
        fontWeight: FontWeight.w500,
      ),
    );
  }
}
