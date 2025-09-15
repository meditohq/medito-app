// ignore_for_file: use_build_context_synchronously

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:medito/constants/constants.dart';
import 'package:medito/providers/device_and_app_info/device_and_app_info_provider.dart';
import 'package:medito/providers/stripe/payment_service_provider.dart';
import 'package:medito/models/stripe/payment_method_model.dart'
    as custom_models;
import 'package:medito/models/stripe/payment_intent_model.dart';
import 'package:medito/models/stripe/payment_error_model.dart';
import 'package:medito/widgets/snackbar_widget.dart';
import 'package:medito/utils/logger.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:medito/widgets/impact_card.dart';
import 'package:medito/l10n/app_localizations.dart';

final _selectedCurrencyProvider = StateProvider<String>((ref) {
  final deviceInfoAsync = ref.watch(deviceAndAppInfoProvider);
  final defaultCurrency = deviceInfoAsync.value?.currencyName ?? 'USD';
  return _getCurrency(defaultCurrency);
});

final _selectedAmountProvider = StateProvider<int>((ref) {
  final paymentConfigAsync = ref.watch(paymentConfigProvider);
  if (paymentConfigAsync.hasValue) {
    final config = paymentConfigAsync.value!;
    return config.pricing.suggested.monthly ~/ 100; // Convert cents to dollars
  }
  return 10; // Fallback
});
final _selectedPaymentMethodProvider =
    StateProvider<custom_models.PaymentMethodType?>((ref) => null);
final _isProcessingPaymentProvider = StateProvider<bool>((ref) => false);
final _customAmountProvider = StateProvider<String>((ref) => '');
final _showCustomAmountProvider = StateProvider<bool>((ref) => false);

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

class DonationScreen extends ConsumerStatefulWidget {
  final int? initialAmount;
  final String? initialCurrency;
  final bool? isMonthly;

  const DonationScreen({
    super.key,
    this.initialAmount,
    this.initialCurrency,
    this.isMonthly,
  });

  @override
  ConsumerState<DonationScreen> createState() => _DonationScreenState();
}

class _DonationScreenState extends ConsumerState<DonationScreen> {
  bool isMonthlyDonationVisible = true;

  @override
  void initState() {
    super.initState();
    // Set initial values from widget parameters
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.initialAmount != null) {
        ref.read(_selectedAmountProvider.notifier).state =
            widget.initialAmount!;
      }
      if (widget.initialCurrency != null) {
        ref.read(_selectedCurrencyProvider.notifier).state =
            widget.initialCurrency!;
      }
      if (widget.isMonthly != null) {
        isMonthlyDonationVisible = widget.isMonthly!;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final selectedCurrency = ref.watch(_selectedCurrencyProvider);
    final paymentConfigAsync = ref.watch(paymentConfigProvider);

    // Preload payment config to ensure Stripe is initialized
    ref.listen(paymentConfigProvider, (previous, next) {
      next.when(
        loading: () =>
            AppLogger.d('DONATION_SCREEN', 'Loading payment config...'),
        error: (error, stack) =>
            AppLogger.e('DONATION_SCREEN', 'Payment config error', error),
        data: (config) => AppLogger.d(
            'DONATION_SCREEN', 'Payment config loaded successfully'),
      );
    });

    // Log payment config status
    paymentConfigAsync.when(
      loading: () =>
          AppLogger.d('DONATION_SCREEN', 'Payment config loading...'),
      error: (error, stack) =>
          AppLogger.e('DONATION_SCREEN', 'Payment config error', error),
      data: (config) => AppLogger.d(
          'DONATION_SCREEN', 'Payment config loaded: ${config.publishableKey}'),
    );

    final currencySymbols = {
      'USD': '\$',
      'GBP': '£',
      'EUR': '€',
      'AUD': 'A\$',
      'INR': '₹',
      'CAD': 'C\$',
    };

    final symbol = currencySymbols[selectedCurrency] ?? '\$';

    // Get default amount from payment config or fallback
    String defaultAmount = '10';
    if (paymentConfigAsync.hasValue) {
      final config = paymentConfigAsync.value!;
      final suggestedAmount =
          config.pricing.suggested.monthly / 100; // Convert cents to dollars
      defaultAmount = suggestedAmount.toStringAsFixed(0);
    }

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.surface,
        elevation: 0,
        automaticallyImplyLeading: false,
        leading: IconButton(
          icon: Icon(Icons.arrow_back,
              color: Theme.of(context).colorScheme.onSurface),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Row(
          children: [
            Icon(HugeIcons.solidSharpSquareLock02,
                color: Theme.of(context).colorScheme.onSurface, size: 18),
            const SizedBox(width: 8),
            Text(
              Platform.isIOS
                  ? AppLocalizations.of(context)!.donateTitle
                  : AppLocalizations.of(context)!.donateToMedito,
              style: Theme.of(context).textTheme.displayLarge,
            ),
          ],
        ),
        actions: [
          _buildCurrencyDropdown(context, selectedCurrency, ref),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              const ImpactCard(),
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.start,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              setState(() {
                                isMonthlyDonationVisible = true;
                              });
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              foregroundColor:
                                  Theme.of(context).colorScheme.onSurface,
                              side: isMonthlyDonationVisible
                                  ? BorderSide(
                                      color:
                                          Theme.of(context).colorScheme.primary)
                                  : BorderSide(color: ColorConstants.softGrey),
                              elevation: 0,
                            ),
                            child: Text(
                              AppLocalizations.of(context)!.monthlyDonation,
                              style: Theme.of(context)
                                  .textTheme
                                  .displayLarge
                                  ?.copyWith(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              setState(() {
                                isMonthlyDonationVisible = false;
                              });
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              foregroundColor:
                                  Theme.of(context).colorScheme.onSurface,
                              side: !isMonthlyDonationVisible
                                  ? BorderSide(
                                      color:
                                          Theme.of(context).colorScheme.primary)
                                  : BorderSide(color: ColorConstants.softGrey),
                              elevation: 0,
                            ),
                            child: Text(
                              AppLocalizations.of(context)!.singleDonation,
                              style: Theme.of(context)
                                  .textTheme
                                  .displayLarge
                                  ?.copyWith(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      isMonthlyDonationVisible
                          ? '$symbol$defaultAmount/month can help 100 people meditate every day.'
                          : AppLocalizations.of(context)!.oneTimeDonationImpact,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontSize: 14,
                            height: 1.5,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.7),
                          ),
                    ),
                    const SizedBox(height: 16),
                    if (isMonthlyDonationVisible)
                      _buildDonationAmountOptions(
                          context, selectedCurrency, true, ref),
                    if (!isMonthlyDonationVisible)
                      _buildDonationAmountOptions(
                          context, selectedCurrency, false, ref),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: _buildPaymentMethodIcons(),
                    ),
                    const SizedBox(height: 24),
                    _buildPaymentMethodSelector(context, ref),
                    const SizedBox(height: 24),
                    _buildDonateButton(context, ref),
                    const SizedBox(height: 32),
                    Text(
                      AppLocalizations.of(context)!.otherPaymentMethods,
                      style: Theme.of(context).textTheme.displayLarge?.copyWith(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const SizedBox(height: 16),
                    _buildOtherPaymentOptions(context),
                    const SizedBox(height: 24),
                    _buildTrustIndicators(context),
                    const SizedBox(height: 24),
                    _buildFoundationInfo(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTrustIndicators(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Padding(
                padding: const EdgeInsets.only(right: 4.0),
                child: Icon(
                  Icons.verified_user_outlined,
                  color: Theme.of(context).colorScheme.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  AppLocalizations.of(context)!.donationSecurityMessage,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontSize: 14,
                        height: 1.4,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.7),
                      ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCurrencyDropdown(
      BuildContext context, String selectedCurrency, WidgetRef ref) {
    final currencySymbols = {
      'USD': '\$',
      'GBP': '£',
      'EUR': '€',
      'AUD': 'A\$',
      'INR': '₹',
      'CAD': 'C\$',
    };

    final symbol = currencySymbols[selectedCurrency] ?? '\$';

    return Container(
      padding: const EdgeInsets.only(right: 16),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            symbol,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.54),
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(width: 2),
          DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: selectedCurrency,
              dropdownColor: Theme.of(context).colorScheme.surface,
              icon: Icon(Icons.arrow_drop_down,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.54),
                  size: 20),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontSize: 14,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
              isDense: true,
              underline: Container(),
              onChanged: (String? newValue) {
                if (newValue != null) {
                  ref.read(_selectedCurrencyProvider.notifier).state = newValue;
                }
              },
              items: const [
                DropdownMenuItem(value: 'USD', child: Text('USD')),
                DropdownMenuItem(value: 'GBP', child: Text('GBP')),
                DropdownMenuItem(value: 'EUR', child: Text('EUR')),
                DropdownMenuItem(value: 'AUD', child: Text('AUD')),
                DropdownMenuItem(value: 'INR', child: Text('INR')),
                DropdownMenuItem(value: 'CAD', child: Text('CAD')),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDonationAmountOptions(
      BuildContext context, String currency, bool isMonthly, WidgetRef ref) {
    final selectedAmount = ref.watch(_selectedAmountProvider);
    final showCustomAmount = ref.watch(_showCustomAmountProvider);
    final paymentConfigAsync = ref.watch(paymentConfigProvider);

    final currencySymbols = {
      'USD': '\$',
      'GBP': '£',
      'EUR': '€',
      'AUD': 'A\$',
      'INR': '₹',
      'CAD': 'C\$',
    };

    final symbol = currencySymbols[currency] ?? '\$';

    // Get preset amounts from payment config or use fallback
    final presetAmounts = <int>[];
    if (paymentConfigAsync.hasValue) {
      final config = paymentConfigAsync.value!;
      final pricingAmounts =
          isMonthly ? config.pricing.monthly : config.pricing.oneTime;
      // Convert from cents to dollars and reverse order for display
      presetAmounts.addAll(
          pricingAmounts.map((amount) => amount ~/ 100).toList().reversed);
    } else {
      // Fallback to hardcoded values if API is not available
      if (currency == 'USD') presetAmounts.addAll([4, 6, 10, 15, 25]);
      if (currency == 'GBP') presetAmounts.addAll([4, 6, 10, 15, 25]);
      if (currency == 'INR') presetAmounts.addAll([327, 490, 816, 1225, 2042]);
      if (currency == 'EUR') presetAmounts.addAll([4, 6, 10, 15, 25]);
      if (currency == 'AUD') presetAmounts.addAll([6, 9, 16, 24, 40]);
      if (currency == 'CAD') presetAmounts.addAll([4, 6, 10, 15, 25]);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 2.5,
          children: presetAmounts.map((amount) {
            final isSelected = selectedAmount == amount && !showCustomAmount;
            final displayText = '$symbol$amount';

            return _buildDonationAmountButton(
              context,
              displayText,
              isSelected,
              () => _selectAmount(ref, amount),
            );
          }).toList(),
        ),
        const SizedBox(height: 16),
        _buildCustomAmountSection(context, currency, ref),
      ],
    );
  }

  void _selectAmount(WidgetRef ref, int amount) {
    // Prevent multiple simultaneous payment attempts
    final isProcessing = ref.read(_isProcessingPaymentProvider);
    if (isProcessing) {
      AppLogger.d('DONATION_SCREEN',
          'Payment already in progress, ignoring amount selection');
      return;
    }

    ref.read(_selectedAmountProvider.notifier).state = amount;
    ref.read(_showCustomAmountProvider.notifier).state = false;
    ref.read(_customAmountProvider.notifier).state = '';

    AppLogger.d(
        'DONATION_SCREEN', 'Amount selected: $amount, triggering payment flow');
    // Automatically trigger payment flow when amount is selected
    _handleDonationAction(context, ref);
  }

  custom_models.PaymentMethodType _getDefaultPaymentMethod() {
    if (Platform.isAndroid) {
      return custom_models.PaymentMethodType.googlePay;
    } else if (Platform.isIOS) {
      return custom_models.PaymentMethodType.applePay;
    } else {
      return custom_models.PaymentMethodType.card;
    }
  }

  Widget _buildCustomAmountSection(
      BuildContext context, String currency, WidgetRef ref) {
    final showCustomAmount = ref.watch(_showCustomAmountProvider);

    final currencySymbols = {
      'USD': '\$',
      'GBP': '£',
      'EUR': '€',
      'AUD': 'A\$',
      'INR': '₹',
      'CAD': 'C\$',
    };

    final symbol = currencySymbols[currency] ?? '\$';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildDonationAmountButton(
          context,
          AppLocalizations.of(context)!.custom,
          showCustomAmount,
          () => ref.read(_showCustomAmountProvider.notifier).state =
              !showCustomAmount,
        ),
        if (showCustomAmount) ...[
          const SizedBox(height: 16),
          TextField(
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              hintText: 'Enter amount',
              prefixText: symbol,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onChanged: (value) {
              ref.read(_customAmountProvider.notifier).state = value;
              if (value.isNotEmpty) {
                final amount = int.tryParse(value) ?? 0;
                if (amount > 0) {
                  ref.read(_selectedAmountProvider.notifier).state = amount;
                }
              }
            },
          ),
        ],
      ],
    );
  }

  Widget _buildOtherPaymentOptions(BuildContext context) {
    return Column(
      children: [
        _buildOtherPaymentButton(
          context,
          AppLocalizations.of(context)!.payWithPaypal,
          'https://paypal.me/meditofoundation',
        ),
        const SizedBox(height: 12),
        _buildOtherPaymentButton(
          context,
          AppLocalizations.of(context)!.bankTransfer,
          'https://meditofoundation.org/about/bank-details',
        ),
      ],
    );
  }

  Widget _buildDonationAmountButton(
    BuildContext context,
    String text,
    bool isSelected,
    VoidCallback onPressed,
  ) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(8),
        splashColor:
            Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
        highlightColor:
            Theme.of(context).colorScheme.primary.withValues(alpha: 0.05),
        child: Container(
          height: 50,
          decoration: BoxDecoration(
            color: isSelected
                ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.1)
                : Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.outline,
              width: 1.2,
            ),
          ),
          alignment: Alignment.center,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                text,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: isSelected
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.onSurface,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOtherPaymentButton(
    BuildContext context,
    String text,
    String url,
  ) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: () => _handleExternalDonationAction(context, url),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
        ),
        child: Text(
          text,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontSize: 16,
                color: Theme.of(context).colorScheme.primary,
              ),
        ),
      ),
    );
  }

  List<Widget> _buildPaymentMethodIcons() {
    return [
      Icon(HugeIcons.solidStandardCreditCardAccept,
          color:
              Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7)),
      const SizedBox(width: 16),
      Icon(FontAwesomeIcons.applePay,
          color:
              Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7)),
      const SizedBox(width: 16),
      Icon(FontAwesomeIcons.googlePay,
          color:
              Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7)),
    ];
  }

  Widget _buildFoundationInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          AppLocalizations.of(context)!.donationSecurityInfo,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.7),
                fontSize: 12,
                height: 1.5,
              ),
        ),
        const SizedBox(height: 8),
        Text(
          AppLocalizations.of(context)!.foundationRegistrationInfo,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.7),
                fontSize: 12,
                height: 1.5,
              ),
        ),
        const SizedBox(height: 8),
        Text(
          AppLocalizations.of(context)!.foundationContactInfo,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.7),
                fontSize: 12,
                height: 1.5,
              ),
        ),
      ],
    );
  }

  Future<void> _handleDonationAction(
      BuildContext context, WidgetRef ref) async {
    // Prevent multiple simultaneous payment attempts
    final isAlreadyProcessing = ref.read(_isProcessingPaymentProvider);
    if (isAlreadyProcessing) {
      AppLogger.d(
          'DONATION_SCREEN', 'Payment already in progress, ignoring request');
      return;
    }

    final selectedPaymentMethod = ref.read(_selectedPaymentMethodProvider);
    final selectedAmount = ref.read(_selectedAmountProvider);
    final selectedCurrency = ref.read(_selectedCurrencyProvider);

    // Validate amount
    if (selectedAmount <= 0) {
      final error = PaymentErrorHandler.handleAmountError(selectedAmount);
      showSnackBar(
        context,
        error.userFriendlyMessage,
      );
      return;
    }

    // Ensure payment config is loaded before proceeding
    final paymentConfigAsync = ref.read(paymentConfigProvider);
    if (paymentConfigAsync.isLoading) {
      showSnackBar(
        context,
        'Loading payment options...',
      );
      return;
    }

    if (paymentConfigAsync.hasError) {
      showSnackBar(
        context,
        'Failed to load payment options. Please try again.',
      );
      return;
    }

    // Set processing state
    ref.read(_isProcessingPaymentProvider.notifier).state = true;

    try {
      showSnackBar(
        context,
        'Processing your donation...',
      );

      // Create PaymentIntent
      final defaultPaymentMethod = _getDefaultPaymentMethod();
      final paymentIntentRequest = PaymentIntentRequest(
        amount: selectedAmount,
        currency: selectedCurrency.toLowerCase(),
        paymentMethod: selectedPaymentMethod?.name ?? defaultPaymentMethod.name,
        isMonthly: isMonthlyDonationVisible,
      );

      AppLogger.d('DONATION_SCREEN',
          'Creating payment intent for amount: $selectedAmount, currency: $selectedCurrency, isMonthly: $isMonthlyDonationVisible');
      AppLogger.d(
          'DONATION_SCREEN', 'Payment intent request: $paymentIntentRequest');

      PaymentIntentModel paymentIntent;
      try {
        paymentIntent = await ref
            .read(createPaymentIntentProvider(paymentIntentRequest).future);

        AppLogger.d('DONATION_SCREEN',
            'Payment intent created successfully: ${paymentIntent.id}, status: ${paymentIntent.status}');
        AppLogger.d('DONATION_SCREEN',
            'Payment intent client secret: ${paymentIntent.clientSecret}');
      } catch (paymentIntentError) {
        AppLogger.e('DONATION_SCREEN', 'Payment intent creation failed',
            paymentIntentError);
        rethrow;
      }

      // Process payment - use platform-specific payment method by default
      final paymentMethod = selectedPaymentMethod ?? _getDefaultPaymentMethod();
      final paymentService = ref.read(paymentServiceProvider);
      AppLogger.d('DONATION_SCREEN',
          'Processing payment with method: ${paymentMethod.name}');

      PaymentResult result;
      try {
        result = await paymentService.processPayment(
          paymentIntent,
          paymentMethod,
        );
        AppLogger.d('DONATION_SCREEN', 'Payment result: ${result.runtimeType}');
      } catch (paymentError) {
        AppLogger.e(
            'DONATION_SCREEN', 'Payment processing failed', paymentError);
        rethrow;
      }

      // Handle result
      switch (result) {
        case PaymentSuccess():
          try {
            // For Google Pay and Apple Pay, confirmation already happened during payment processing
            // Only confirm for card payments
            if (paymentMethod.name == 'card') {
              final donationData = DonationData(
                amount: selectedAmount,
                currency: selectedCurrency,
                isMonthly: isMonthlyDonationVisible,
                paymentMethod: paymentMethod.name,
              );

              final paymentService = ref.read(paymentServiceProvider);
              await paymentService.confirmDonation(
                paymentIntent.id,
                donationData,
              );
            }

            showSnackBar(
              context,
              'Thank you for your donation! Your support helps us continue our mission.',
            );
          } catch (confirmError) {
            // Payment succeeded but confirmation failed - still show success but log error
            showSnackBar(
              context,
              'Donation successful! Thank you for your support.',
            );
            // In a real app, you'd log this error for monitoring
          }
          break;

        case PaymentFailure():
          showSnackBar(
            context,
            result.errorMessage,
          );
          break;

        case PaymentCancelled():
          showSnackBar(
            context,
            'Payment cancelled',
          );
          break;
      }
    } catch (error) {
      AppLogger.e('DONATION_SCREEN', 'Donation action failed', error);
      final paymentError = PaymentErrorHandler.handleStripeError(error);
      showSnackBar(
        context,
        paymentError.userFriendlyMessage,
      );

      if (paymentError.suggestedAction != null) {
        // Show additional guidance after a brief delay
        Future.delayed(const Duration(seconds: 3), () {
          if (context.mounted) {
            showSnackBar(
              context,
              paymentError.suggestedAction!,
            );
          }
        });
      }
    } finally {
      ref.read(_isProcessingPaymentProvider.notifier).state = false;
    }
  }

  Widget _buildPaymentMethodSelector(BuildContext context, WidgetRef ref) {
    final availableMethodsAsync = ref.watch(availablePaymentMethodsProvider);
    final selectedPaymentMethod = ref.watch(_selectedPaymentMethodProvider);

    return availableMethodsAsync.when(
      loading: () => const CircularProgressIndicator() as Widget,
      error: (error, stack) =>
          Text('Error loading payment methods: $error') as Widget,
      data: (List<custom_models.PaymentMethod> methods) {
        if (methods.isEmpty) {
          return const Text('No payment methods available');
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Select Payment Method',
              style: Theme.of(context).textTheme.displayLarge?.copyWith(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: methods.map((custom_models.PaymentMethod method) {
                final isSelected = selectedPaymentMethod == method.type;
                return _buildPaymentMethodButton(
                  context,
                  method,
                  isSelected,
                  () => ref
                      .read(_selectedPaymentMethodProvider.notifier)
                      .state = method.type,
                );
              }).toList(),
            ),
          ],
        );
      },
    );
  }

  Widget _buildPaymentMethodButton(
    BuildContext context,
    custom_models.PaymentMethod method,
    bool isSelected,
    VoidCallback onPressed,
  ) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: method.isAvailable ? onPressed : null,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isSelected
                ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.1)
                : Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.outline,
              width: 1.2,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _getPaymentMethodIcon(method.type),
                color: method.isAvailable
                    ? (isSelected
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.onSurface)
                    : Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.4),
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                method.displayName,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: method.isAvailable
                          ? (isSelected
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(context).colorScheme.onSurface)
                          : Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.4),
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getPaymentMethodIcon(custom_models.PaymentMethodType type) {
    switch (type) {
      case custom_models.PaymentMethodType.googlePay:
        return FontAwesomeIcons.googlePay;
      case custom_models.PaymentMethodType.applePay:
        return FontAwesomeIcons.applePay;
      case custom_models.PaymentMethodType.card:
        return HugeIcons.solidStandardCreditCardAccept;
      case custom_models.PaymentMethodType.paypal:
        return FontAwesomeIcons.paypal;
      case custom_models.PaymentMethodType.bankTransfer:
        return HugeIcons.solidStandardBank;
    }
  }

  Widget _buildDonateButton(BuildContext context, WidgetRef ref) {
    final isProcessing = ref.watch(_isProcessingPaymentProvider);
    final selectedAmount = ref.watch(_selectedAmountProvider);
    final selectedCurrency = ref.watch(_selectedCurrencyProvider);

    final currencySymbols = {
      'USD': '\$',
      'GBP': '£',
      'EUR': '€',
      'AUD': 'A\$',
      'INR': '₹',
      'CAD': 'C\$',
    };

    final symbol = currencySymbols[selectedCurrency] ?? '\$';
    final amountText =
        selectedAmount > 0 ? '$symbol$selectedAmount' : 'Select amount';

    return Column(
      children: [
        Text(
          'Tap an amount above to start your donation',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.7),
                fontSize: 14,
              ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: (isProcessing || selectedAmount <= 0)
                ? null
                : () => _handleDonationAction(context, ref),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              side: BorderSide(
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            child: isProcessing
                ? const CircularProgressIndicator()
                : Text(
                    'Donate $amountText',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                  ),
          ),
        ),
      ],
    );
  }

  // Legacy method for external payments (PayPal, Bank Transfer)
  void _handleExternalDonationAction(BuildContext context, String url) async {
    showSnackBar(
      context,
      AppLocalizations.of(context)!.redirectingToSecurePayment,
    );

    await Future.delayed(Duration(milliseconds: 2));

    final Uri uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.inAppBrowserView);
    } else {
      showSnackBar(
        context,
        AppLocalizations.of(context)!.couldNotOpenDonationPage,
      );
    }
  }
}
