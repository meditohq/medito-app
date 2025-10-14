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
import 'package:superwallkit_flutter/superwallkit_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class SuperwallDonationScreen extends ConsumerStatefulWidget {
  const SuperwallDonationScreen({super.key});

  @override
  ConsumerState<SuperwallDonationScreen> createState() =>
      _SuperwallDonationScreenState();
}

class _SuperwallDonationScreenState
    extends ConsumerState<SuperwallDonationScreen> {
  bool _hasTriggeredPaywall = false;
  bool _isLoading = true;
  bool _isProcessingPayment = false;

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
      AppLogger.d('SUPERWALL_DONATION_SCREEN', 'Starting paywall trigger');

      // Get payment config to pass currency and pricing data to Superwall
      // Add error handling for payment config loading failures
      try {
        await ref.read(paymentConfigProvider.future);
      } catch (paymentConfigError) {
        AppLogger.e(
            'SUPERWALL_DONATION_SCREEN',
            'Failed to load payment config, falling back to web donation',
            paymentConfigError);
        // If payment config fails (e.g., API not deployed to prod),
        // fall back to web donation
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
          await _fallbackToWebDonation();
          return;
        }
      }

      final paywallManager = ref.read(paywallManagerServiceProvider);

      await paywallManager.triggerDonationPaywall(
        onPaywallPresented: () {
          if (mounted) {
            setState(() {
              _isLoading = false;
            });
          }
        },
        onPaywallDismissed: () {
          AppLogger.d('SUPERWALL_DONATION_SCREEN', 'Paywall dismissed');
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

      // Get payment config for currency
      final paymentConfig = await ref.read(paymentConfigProvider.future);

      // Get available payment methods
      final availableMethods =
          await ref.read(availablePaymentMethodsProvider.future);

      if (availableMethods.isEmpty) {
        AppLogger.w('SUPERWALL_DONATION_SCREEN',
            'No payment methods available, falling back to web donation');
        await _fallbackToWebDonation();
        return;
      }

      // Choose the best payment method (prioritize platform pay)
      payment_models.PaymentMethod selectedMethod = availableMethods.first;

      // Prefer Google Pay or Apple Pay over card payments
      for (final method in availableMethods) {
        if (method.type == payment_models.PaymentMethodType.googlePay ||
            method.type == payment_models.PaymentMethodType.applePay) {
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
        );
      } else {
        await uiController.initiateOneTimePayment(
          context: context,
          amount: amountInCents,
          currency: paymentConfig.pricing.currency,
          paymentMethod: selectedMethod.type,
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
