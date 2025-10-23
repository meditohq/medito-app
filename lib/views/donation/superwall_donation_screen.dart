// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medito/providers/stripe/payment_service_provider.dart';
import 'package:medito/providers/stripe/payment_ui_controller.dart';
import 'package:medito/models/stripe/payment_method_model.dart'
    as payment_models;
import 'package:medito/widgets/snackbar_widget.dart';
import 'package:medito/utils/logger.dart';
import 'package:medito/l10n/app_localizations.dart';
import 'package:medito/services/paywall_manager_service.dart';
import 'package:medito/services/analytics/firebase_analytics_service.dart';
import 'package:medito/repositories/auth/auth_repository.dart';
import 'package:superwallkit_flutter/superwallkit_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class SuperwallDonationScreen extends ConsumerStatefulWidget {
  const SuperwallDonationScreen({super.key, this.source});

  final String? source;

  @override
  ConsumerState<SuperwallDonationScreen> createState() =>
      _SuperwallDonationScreenState();
}

class _SuperwallDonationScreenState
    extends ConsumerState<SuperwallDonationScreen> {
  bool _hasTriggeredPaywall = false;
  bool _isLoading = true;
  bool _isProcessingPayment = false;
  String? _currentPaywallId;
  String? _completedPaywallId;

  @override
  void initState() {
    super.initState();
    // Trigger Superwall paywall as soon as the screen loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _triggerSuperwallPaywall();
      // Add timeout to prevent infinite loading
      _addTimeoutFallback();
    });
  }

  @override
  void dispose() {
    // Clean up Pay clients when the screen is disposed
    // This helps prevent event channel conflicts
    super.dispose();
  }

  void _addTimeoutFallback() {
    Future.delayed(const Duration(seconds: 10), () {
      if (mounted && _isLoading) {
        AppLogger.w('SUPERWALL_DONATION_SCREEN',
            'Paywall loading timeout - falling back to web donation');
        setState(() {
          _isLoading = false;
        });
        _fallbackToWebDonation();
      }
    });
  }

  Future<void> _triggerSuperwallPaywall() async {
    if (_hasTriggeredPaywall) return;
    _hasTriggeredPaywall = true;

    try {
      final paywallManager = ref.read(paywallManagerServiceProvider);

      await paywallManager.triggerDonationPaywall(
        onPaywallPresented: (String paywallId) {
          if (mounted) {
            setState(() {
              _isLoading = false;
              _currentPaywallId = paywallId;
            });
          }
        },
        onPaywallDismissed: (String paywallId) {
          AppLogger.d('SUPERWALL_DONATION_SCREEN', 'Paywall dismissed');

          // Only track as "no payment" if we didn't complete a donation
          if (_completedPaywallId != paywallId) {
            final userId =
                ref.read(authRepositorySyncProvider).currentUser?.id ??
                    'unknown';

            FirebaseAnalyticsService().logEvent(
              name: FirebaseAnalyticsService.eventPaywallDismissedNoPayment,
              parameters: {
                'paywall_id': paywallId,
                'user_id': userId,
              },
            );
          }

          // Only close the screen if we're NOT processing a payment
          // If payment is being processed, let the payment flow handle screen closure
          if (mounted && !_isProcessingPayment) {
            AppLogger.d(
                'SUPERWALL_DONATION_SCREEN', 'User cancelled - closing screen');
            Navigator.of(context).pop();
          } else if (_isProcessingPayment) {
            AppLogger.d('SUPERWALL_DONATION_SCREEN',
                'Payment in progress - keeping screen open for completion');
          }
        },
        onError: (error) {
          if (mounted) {
            setState(() {
              _isLoading = false;
            });
            _handlePaywallError(error);
          }
        },
        onDonationInitiated: (amount, isMonthly) async {
          AppLogger.d('SUPERWALL_DONATION_SCREEN',
              'Donation initiated: amount: $amount, isMonthly: $isMonthly');

          // Mark that we're processing payment so onPaywallDismissed doesn't close the screen
          _isProcessingPayment = true;

          AppLogger.d(
              'SUPERWALL_DONATION_SCREEN', 'Dismissing Superwall paywall...');
          Superwall.shared.dismiss();

          // Trigger native payment sheet instead of just showing snackbar
          if (mounted) {
            await _processDonationPayment(context, amount, isMonthly);
          }
        },
      );
    } catch (error) {
      AppLogger.e(
          'SUPERWALL_DONATION_SCREEN',
          'Failed to trigger Superwall paywall, falling back to web donation',
          error);
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        await _fallbackToWebDonation();
      }
    }
  }

  void _handlePaywallError(String error) {
    AppLogger.w('SUPERWALL_DONATION_SCREEN', 'Paywall error: $error');
    // For any paywall error, fall back to web donation
    _fallbackToWebDonation();
  }

  /// Process the donation payment using native payment methods
  Future<void> _processDonationPayment(
      BuildContext context, num amount, bool isMonthly) async {
    try {
      AppLogger.d('SUPERWALL_DONATION_SCREEN',
          'Processing donation payment: amount=$amount, isMonthly=$isMonthly');

      final uiController = ref.read(paymentUIControllerProvider.notifier);
      final paywallId = _currentPaywallId ?? 'unknown';
      final authRepository = ref.read(authRepositorySyncProvider);
      final userId = authRepository.currentUser?.id ?? 'unknown';

      // Check if user is logged in
      final isLoggedIn = await authRepository.isLoggedIn();
      String? userEmail = authRepository.currentUser?.email;

      // If user is not logged in, collect email for identification
      if (!isLoggedIn || (userEmail == null || userEmail.isEmpty)) {
        AppLogger.d('SUPERWALL_DONATION_SCREEN',
            'User not logged in or no email - collecting email for payment identification');

        userEmail = await _collectEmailForPayment(context);
        if (userEmail == null) {
          if (mounted) {
            Navigator.of(context).pop();
          }
          return;
        }
      }

      // Get payment config for currency
      final paymentConfig = await ref.read(paymentConfigProvider.future);

      // Get available payment methods
      final availableMethods =
          await ref.read(availablePaymentMethodsProvider.future);

      if (availableMethods.isEmpty) {
        await _fallbackToWebDonation();
        return;
      }

      // Choose the best payment method (prioritize platform pay)
      payment_models.PaymentMethod selectedMethod = availableMethods.first;

      // Prefer Apple Pay over card payments
      for (final method in availableMethods) {
        if (method.type == payment_models.PaymentMethodType.applePay) {
          selectedMethod = method;
          break;
        }
      }

      AppLogger.d('SUPERWALL_DONATION_SCREEN',
          'Selected payment method: ${selectedMethod.type}');

      // Amount is already in cents from Superwall
      final amountInCents = amount.toInt();

      // Trigger the appropriate payment based on type
      AppLogger.d('SUPERWALL_DONATION_SCREEN',
          'Initiating ${isMonthly ? "monthly subscription" : "one-time payment"} for $amountInCents cents (${(amountInCents / 100).toStringAsFixed(2)} ${paymentConfig.pricing.currency})');

      if (isMonthly) {
        await uiController.initiateMonthlySubscription(
          context: context,
          amount: amountInCents,
          currency: paymentConfig.pricing.currency,
          paymentMethod: selectedMethod.type,
          paywallId: paywallId,
          userId: userId,
          userEmail: userEmail,
          paywallSource: widget.source,
          onSuccess: () {
            _completedPaywallId = paywallId;
          },
        );
      } else {
        await uiController.initiateOneTimePayment(
          context: context,
          amount: amountInCents,
          currency: paymentConfig.pricing.currency,
          paymentMethod: selectedMethod.type,
          paywallId: paywallId,
          userId: userId,
          userEmail: userEmail,
          paywallSource: widget.source,
          onSuccess: () {
            _completedPaywallId = paywallId;
          },
        );
      }

      AppLogger.d(
          'SUPERWALL_DONATION_SCREEN', 'Payment flow completed successfully');

      // Close the screen immediately - the global snackbar will show regardless
      if (mounted) {
        AppLogger.d('SUPERWALL_DONATION_SCREEN',
            'Closing donation screen after successful payment');
        Navigator.of(context).pop();
      }
    } catch (error) {
      AppLogger.e('SUPERWALL_DONATION_SCREEN',
          'Failed to process donation payment', error);

      if (mounted) {
        showSnackBar(
          context,
          AppLocalizations.of(context)!.unableToLoadDonationOptionsAtThisTime,
        );

        // Close the screen immediately - the global snackbar will show regardless
        Navigator.of(context).pop();
      }
    } finally {
      _isProcessingPayment = false;
    }
  }

  /// Collect email address from anonymous users for payment identification
  Future<String?> _collectEmailForPayment(BuildContext context) async {
    final emailController = TextEditingController();
    final focusNode = FocusNode();
    String? email;

    await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        // Use StatefulBuilder to request focus after build
        return StatefulBuilder(
          builder: (context, setState) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!focusNode.hasFocus) {
                focusNode.requestFocus();
              }
            });

            return PopScope(
              canPop: false, // Prevent back button from dismissing dialog
              child: AlertDialog(
                title: Text(AppLocalizations.of(context)!.emailForReceipt),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(AppLocalizations.of(context)!
                        .emailForReceiptDescription),
                    const SizedBox(height: 16),
                    TextField(
                      controller: emailController,
                      focusNode: focusNode,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        labelText: AppLocalizations.of(context)!.email,
                        border: const OutlineInputBorder(),
                      ),
                      autofocus: true,
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () {
                      final enteredEmail = emailController.text.trim();
                      if (_isValidEmail(enteredEmail)) {
                        Navigator.of(dialogContext).pop(enteredEmail);
                      } else {
                        ScaffoldMessenger.of(dialogContext).showSnackBar(
                          SnackBar(
                            content: Text(
                                AppLocalizations.of(context)!.invalidEmail),
                          ),
                        );
                      }
                    },
                    child: Text(AppLocalizations.of(context)!.next),
                  ),
                ],
              ),
            );
          },
        );
      },
    ).then((result) {
      email = result;
      focusNode.dispose();
    });

    return email;
  }

  /// Simple email validation
  bool _isValidEmail(String email) {
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    return emailRegex.hasMatch(email);
  }

  /// Fallback method to open web donation when API fails
  Future<void> _fallbackToWebDonation() async {
    try {
      AppLogger.d('SUPERWALL_DONATION_SCREEN', 'Opening web donation fallback');
      final uri = Uri.parse('https://meditofoundation.org/donate');
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          showSnackBar(
            context,
            AppLocalizations.of(context)!.unableToLoadDonationOptionsAtThisTime,
          );
        }
      }
    } catch (error) {
      AppLogger.e(
          'SUPERWALL_DONATION_SCREEN', 'Failed to open web donation', error);
      if (mounted) {
        showSnackBar(
          context,
          AppLocalizations.of(context)!.unableToLoadDonationOptionsAtThisTime,
        );
      }
    } finally {
      if (mounted) {
        Navigator.of(context).pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Show a minimal loading screen while the paywall is being prepared
    // The actual paywall will appear as a full-screen overlay
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 24),
              Text(
                _isLoading
                    ? AppLocalizations.of(context)!.loadingDonationOptions
                    : AppLocalizations.of(context)!.preparingDonation,
                style: Theme.of(context).textTheme.bodyLarge,
                textAlign: TextAlign.center,
              ),
              if (_isLoading) ...[
                const SizedBox(height: 16),
                Text(
                  AppLocalizations.of(context)!.thisMayTakeAMoment,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.6),
                      ),
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
