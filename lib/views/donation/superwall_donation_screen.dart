// ignore_for_file: use_build_context_synchronously

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medito/models/stripe/payment_config_model.dart';
import 'package:medito/providers/device_and_app_info/device_and_app_info_provider.dart';
import 'package:medito/providers/stripe/payment_service_provider.dart';
import 'package:medito/widgets/snackbar_widget.dart';
import 'package:medito/utils/logger.dart';
import 'package:medito/l10n/app_localizations.dart';
import 'package:medito/services/paywall_manager_service.dart';
import 'package:medito/models/stripe/payment_intent_model.dart';
import 'package:medito/models/stripe/payment_method_model.dart'
    as custom_models;
import 'package:medito/models/stripe/payment_error_model.dart';
import 'package:superwallkit_flutter/superwallkit_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

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
      PaymentConfigModel? paymentConfig;
      try {
        paymentConfig = await ref.read(paymentConfigProvider.future);
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

      // Get device currency as fallback
      final deviceInfo = ref.read(deviceAndAppInfoProvider).value;
      final fallbackCurrency = _getCurrency(deviceInfo?.currencyName);
      final currency = paymentConfig?.currencyCode.isNotEmpty == true
          ? paymentConfig!.currencyCode
          : fallbackCurrency;

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
      AppLogger.e(
          'SUPERWALL_DONATION_SCREEN',
          'Failed to trigger Superwall paywall, falling back to web donation',
          error);
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isShowingPaymentSheet = false;
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

  Future<void> _processDonationPayment(
      int amount, bool isMonthly, String currency) async {
    try {
      AppLogger.d('SUPERWALL_DONATION_SCREEN',
          'Processing donation payment: $amount $currency, monthly: $isMonthly');

      showSnackBar(context, AppLocalizations.of(context)!.processing);

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
            }
          }

          _isShowingPaymentSheet = false;
          showSnackBar(
            context,
            AppLocalizations.of(context)!.thankYouForDonationMessage,
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
          showSnackBar(context, AppLocalizations.of(context)!.paymentCancelled);
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

  custom_models.PaymentMethodType _getDefaultPaymentMethod() {
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
              if (!_isShowingPaymentSheet) const CircularProgressIndicator(),
              const SizedBox(height: 24),
              Text(
                _isLoading
                    ? AppLocalizations.of(context)!.loadingDonationOptions
                    : _isShowingPaymentSheet
                        ? AppLocalizations.of(context)!.processingPayment
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
