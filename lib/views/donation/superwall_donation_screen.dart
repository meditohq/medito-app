// ignore_for_file: use_build_context_synchronously

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medito/providers/device_and_app_info/device_and_app_info_provider.dart';
import 'package:medito/providers/stripe/payment_service_provider.dart';
import 'package:medito/widgets/snackbar_widget.dart';
import 'package:medito/utils/logger.dart';
import 'package:medito/l10n/app_localizations.dart';
import 'package:medito/views/donation/donation_screen.dart';
import 'package:medito/services/paywall_manager_service.dart';
import 'package:medito/models/stripe/payment_intent_model.dart';
import 'package:medito/models/stripe/payment_method_model.dart'
    as custom_models;
import 'package:medito/models/stripe/payment_error_model.dart';
import 'package:superwallkit_flutter/superwallkit_flutter.dart';

String _getCurrency(String? deviceCurrency) {
  if (deviceCurrency == null) return 'USD';

  // Map device currency to our supported currencies
  if (deviceCurrency.contains('USD')) return 'USD';
  if (deviceCurrency.contains('GBP')) return 'GBP';
  if (deviceCurrency.contains('EUR')) return 'EUR';
  if (deviceCurrency.contains('AUD')) return 'AUD';
  if (deviceCurrency.contains('INR')) return 'INR';
  if (deviceCurrency.contains('CAD')) return 'CAD';

  // Default to USD if not in our supported list
  return 'USD';
}

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
  bool _isShowingPaymentSheet = false;

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

  void _addTimeoutFallback() {
    Future.delayed(const Duration(seconds: 10), () {
      if (mounted && _isLoading) {
        AppLogger.w('SUPERWALL_DONATION_SCREEN',
            'Paywall loading timeout - showing retry option');
        _showRetryDialog();
      }
    });
  }

  void _showRetryDialog() {
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Connection Issue'),
          content: const Text(
            'Unable to load donation options. Would you like to try again or use our standard donation method?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close dialog
                Navigator.of(context).pop(); // Go back
                // Navigate to regular donation screen
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(
                    builder: (context) => const DonationScreen(),
                  ),
                );
              },
              child: const Text('Use Standard Method'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close dialog
                // Retry Superwall
                setState(() {
                  _isLoading = true;
                  _hasTriggeredPaywall = false;
                  _isShowingPaymentSheet = false;
                });
                _triggerSuperwallPaywall();
                _addTimeoutFallback(); // Reset timeout
              },
              child: const Text('Try Again'),
            ),
          ],
        ),
      );
    }
  }

  void _showPaywallNotConfiguredDialog() {
    if (mounted) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Paywall Not Configured'),
          content: const Text(
            'The donation paywall is not yet configured in Superwall. Please configure the "donation_flow" event in your Superwall dashboard, or use our standard donation method.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close dialog
                Navigator.of(context).pop(); // Go back to previous screen
                // Navigate to regular donation screen
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(
                    builder: (context) => const DonationScreen(),
                  ),
                );
              },
              child: const Text('Use Standard Method'),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _triggerSuperwallPaywall() async {
    if (_hasTriggeredPaywall) return;
    _hasTriggeredPaywall = true;

    try {
      // Get payment config to pass currency and pricing data to Superwall
      final paymentConfig = await ref.read(paymentConfigProvider.future);
      final paywallManager = ref.read(paywallManagerServiceProvider);

      // Get device currency as fallback
      final deviceInfo = ref.read(deviceAndAppInfoProvider).value;
      final fallbackCurrency = _getCurrency(deviceInfo?.currencyName);
      final currency = paymentConfig.currencyCode.isNotEmpty
          ? paymentConfig.currencyCode
          : fallbackCurrency;

      await paywallManager.triggerDonationPaywall(
        currency: currency,
        prices: paymentConfig.pricing,
        onPaywallPresented: () {
          if (mounted) {
            setState(() {
              _isLoading = false;
            });
          }
        },
        onPaywallDismissed: () {
          AppLogger.d('SUPERWALL_DONATION_SCREEN', 'Paywall dismissed');
          // Only pop the screen if we're not about to show a payment sheet
          if (mounted && !_isShowingPaymentSheet) {
            Navigator.of(context).pop();
          }
        },
        onError: (error) {
          if (mounted) {
            setState(() {
              _isLoading = false;
              _isShowingPaymentSheet = false;
            });
            _handlePaywallError(error);
          }
        },
        onDonationInitiated: (amount, isMonthly) {
          _isShowingPaymentSheet = true;
          Superwall.shared.dismiss();
          AppLogger.d('SUPERWALL_DONATION_SCREEN',
              'Donation initiated: amount: $amount, isMonthly: $isMonthly');
          // Add a small delay to ensure the paywall dismiss action from web console
          // has time to complete before presenting the payment sheet
          // This prevents the "Can not perform this action after onSaveInstanceState" error
          if (mounted) {
            Future.delayed(const Duration(milliseconds: 500), () {
              _processDonationPayment(amount, isMonthly, currency);
            });
          }
        },
      );
    } catch (error) {
      AppLogger.e('SUPERWALL_DONATION_SCREEN',
          'Failed to trigger Superwall paywall', error);
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isShowingPaymentSheet = false;
        });
        showSnackBar(context, 'Unable to load donation options at this time.');
        Navigator.of(context).pop();
      }
    }
  }

  void _handlePaywallError(String error) {
    if (error == 'Paywall not configured' ||
        error == 'Paywall placement not found') {
      _showPaywallNotConfiguredDialog();
    } else {
      // For other errors, show fallback dialog
      AppLogger.w('SUPERWALL_DONATION_SCREEN', 'Paywall error: $error');
      _showRetryDialog();
    }
  }

  Future<void> _processDonationPayment(
      int amount, bool isMonthly, String currency) async {
    try {
      AppLogger.d('SUPERWALL_DONATION_SCREEN',
          'Processing donation payment: $amount $currency, monthly: $isMonthly');

      showSnackBar(context, 'Processing...');

      // Create PaymentIntent
      final paymentIntentRequest = PaymentIntentRequest(
        amount: amount ~/ 100, // Convert from cents to dollars
        currency: currency.toLowerCase(),
        paymentMethod: _getDefaultPaymentMethod().name,
        isMonthly: isMonthly,
      );

      final paymentIntent = await ref
          .read(createPaymentIntentProvider(paymentIntentRequest).future);

      AppLogger.d('SUPERWALL_DONATION_SCREEN',
          'Payment intent created: ${paymentIntent.id}');

      // Get the best available payment method for the platform
      final paymentMethod = _getDefaultPaymentMethod();
      final paymentService = ref.read(paymentServiceProvider);

      AppLogger.d('SUPERWALL_DONATION_SCREEN',
          'Processing payment with method: ${paymentMethod.name}');

      final result = await paymentService.processPayment(
        paymentIntent,
        paymentMethod,
      );

      // Handle payment result
      switch (result) {
        case PaymentSuccess():
          // For Google Pay and Apple Pay, confirmation already happened during payment processing
          // Only confirm for card payments
          if (paymentMethod.name == 'card') {
            final donationData = DonationData(
              amount: amount,
              currency: currency,
              isMonthly: isMonthly,
              paymentMethod: paymentMethod.name,
            );

            try {
              await paymentService.confirmDonation(
                paymentIntent.id,
                donationData,
              );
            } catch (confirmError) {
              AppLogger.e('SUPERWALL_DONATION_SCREEN',
                  'Donation confirmation failed', confirmError);
              Navigator.of(context).pop();
              // Payment succeeded but confirmation failed - still show success
            }
          }

          _isShowingPaymentSheet = false;
          showSnackBar(
            context,
            'Thank you for your donation! Your support helps us continue our mission.',
          );

          Navigator.of(context).pop();

          break;

        case PaymentFailure():
          _isShowingPaymentSheet = false;
          showSnackBar(context, result.errorMessage);
          Navigator.of(context).pop();
          break;

        case PaymentCancelled():
          _isShowingPaymentSheet = false;
          showSnackBar(context, 'Payment cancelled');
          Navigator.of(context).pop();
          break;
      }
    } catch (error) {
      _isShowingPaymentSheet = false;
      AppLogger.e(
          'SUPERWALL_DONATION_SCREEN', 'Donation payment failed', error);
      final paymentError = PaymentErrorHandler.handleStripeError(error);
      showSnackBar(context, paymentError.userFriendlyMessage);
      Navigator.of(context).pop();
    }
  }

  custom_models.PaymentMethodType _getDefaultPaymentMethod() {
    // Return platform-specific default payment method
    if (Platform.isIOS) {
      return custom_models.PaymentMethodType.applePay;
    } else if (Platform.isAndroid) {
      return custom_models.PaymentMethodType.googlePay;
    } else {
      return custom_models.PaymentMethodType.card;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Show a minimal loading screen while the paywall is being prepared
    // The actual paywall will appear as a full-screen overlay
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.surface,
        elevation: 0,
        automaticallyImplyLeading: true, // Allow back navigation while loading
        title: Text(
          AppLocalizations.of(context)!.donateToMedito,
          style: Theme.of(context).textTheme.displayLarge,
        ),
      ),
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 24),
              Text(
                _isLoading
                    ? 'Loading donation options...'
                    : 'Preparing donation...',
                style: Theme.of(context).textTheme.bodyLarge,
                textAlign: TextAlign.center,
              ),
              if (_isLoading) ...[
                const SizedBox(height: 16),
                Text(
                  'This may take a moment',
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
