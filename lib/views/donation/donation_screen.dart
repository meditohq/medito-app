import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:medito/constants/constants.dart';
import 'package:medito/providers/device_and_app_info/device_and_app_info_provider.dart';
import 'package:medito/widgets/snackbar_widget.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:medito/widgets/impact_card.dart';

final _selectedCurrencyProvider = StateProvider<String>((ref) {
  final deviceInfoAsync = ref.watch(deviceAndAppInfoProvider);
  final defaultCurrency = deviceInfoAsync.value?.currencyName ?? 'USD';
  return _getCurrency(defaultCurrency);
});

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
  const DonationScreen({super.key});

  @override
  ConsumerState<DonationScreen> createState() => _DonationScreenState();
}

class _DonationScreenState extends ConsumerState<DonationScreen> {
  bool isMonthlyDonationVisible = true;

  @override
  Widget build(BuildContext context) {
    final selectedCurrency = ref.watch(_selectedCurrencyProvider);

    final currencySymbols = {
      'USD': '\$',
      'GBP': '£',
      'EUR': '€',
      'AUD': 'A\$',
      'INR': '₹',
      'CAD': 'C\$',
    };

    final amounts = {
      'USD': '10',
      'GBP': '10',
      'EUR': '10',
      'AUD': '16',
      'INR': '816',
      'CAD': '10',
    };

    final symbol = currencySymbols[selectedCurrency] ?? '\$';
    final amount = amounts[selectedCurrency] ?? '10';

    return Scaffold(
      backgroundColor: ColorConstants.ebony,
      appBar: AppBar(
        backgroundColor: ColorConstants.onyx,
        elevation: 0,
        automaticallyImplyLeading: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Row(
          children: [
            Icon(HugeIcons.solidSharpSquareLock02,
                color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Text(
              StringConstants.donateToMedito,
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
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                  borderRadius:
                                      BorderRadius.all(Radius.circular(8))),
                              side: isMonthlyDonationVisible
                                  ? BorderSide(
                                      color: ColorConstants.lightPurple)
                                  : BorderSide(color: ColorConstants.softGrey),
                              elevation: 0,
                            ),
                            child: const Text(
                              StringConstants.monthlyDonation,
                              style: TextStyle(
                                color: Colors.white,
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
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                  borderRadius:
                                      BorderRadius.all(Radius.circular(8))),
                              side: !isMonthlyDonationVisible
                                  ? BorderSide(
                                      color: ColorConstants.lightPurple)
                                  : BorderSide(color: ColorConstants.softGrey),
                              elevation: 0,
                            ),
                            child: Text(
                              StringConstants.singleDonation,
                              style: const TextStyle(
                                color: Colors.white,
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
                          ? '$symbol$amount/month can help 100 people meditate every day.'
                          : StringConstants.oneTimeDonationImpact,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (isMonthlyDonationVisible)
                      _buildDonationAmountOptions(
                          context, selectedCurrency, true),
                    if (!isMonthlyDonationVisible)
                      _buildDonationAmountOptions(
                          context, selectedCurrency, false),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: _buildPaymentMethodIcons(),
                    ),
                    const SizedBox(height: 32),
                    Text(
                      StringConstants.otherPaymentMethods,
                      style: const TextStyle(
                        color: Colors.white,
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
        color: ColorConstants.greyIsTheNewGrey.withAlpha(77),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: ColorConstants.lightPurple.withAlpha(77),
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
                child: const Icon(
                  Icons.verified_user_outlined,
                  color: ColorConstants.lightPurple,
                  size: 20,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  StringConstants.donationSecurityMessage,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                    height: 1.4,
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
            style: TextStyle(
              color: Colors.white54,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 2),
          DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: selectedCurrency,
              dropdownColor: ColorConstants.greyIsTheNewBlack,
              icon: const Icon(Icons.arrow_drop_down,
                  color: Colors.white54, size: 20),
              style: const TextStyle(color: Colors.white, fontSize: 14),
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
      BuildContext context, String currency, bool isMonthly) {
    final amounts = <String, String>{};

    if (currency == 'USD') {
      amounts['4'] = 'https://buy.stripe.com/5kA5lG3jn5TFgnu7t2';
      amounts['6'] = 'https://buy.stripe.com/dR601m4nr3Lx0owdRr';
      amounts['10'] = 'https://buy.stripe.com/5kAg0kbPT0zl2wE14G';
      amounts['15'] = 'https://buy.stripe.com/6oE01m6vzgyj0ow4gT';
      amounts['25'] = 'https://buy.stripe.com/14k6pK4nr1Dp9Z67t6';
      amounts[StringConstants.custom] =
          'https://donate.stripe.com/fZeg0kf25dm79Z63cx';
    }

    if (currency == 'GBP') {
      amounts['4'] = 'https://buy.stripe.com/00g6pK4nr95R9Z6fZD';
      amounts['6'] = 'https://buy.stripe.com/00g6pK2fj0zlgnu3cS';
      amounts['10'] = 'https://buy.stripe.com/aEU15qbPTfufdbi00H';
      amounts['15'] = 'https://buy.stripe.com/9AQ5lG7zDeqb6MU8xe';
      amounts['25'] = 'https://buy.stripe.com/28o3dy6vz95R0ow4gZ';
      amounts[StringConstants.custom] =
          'https://donate.stripe.com/aEUcO85rvbdZ1sA7sO';
    }

    if (currency == 'INR') {
      amounts['327'] = 'https://buy.stripe.com/fZe4hC3jn2Ht3AIcNG';
      amounts['490'] = 'https://buy.stripe.com/6oEdSc2fj81N3AI00V';
      amounts['816'] = 'https://buy.stripe.com/eVaaG007b95RgnuaFA';
      amounts['1225'] = 'https://buy.stripe.com/cN27tO3jn2Htc7e151';
      amounts['2042'] = 'https://buy.stripe.com/28og0kdY11Dpb3a152';
      amounts[StringConstants.custom] =
          'https://donate.stripe.com/dR66pK8DH3Lxb3a8wU';
    }

    if (currency == 'EUR') {
      amounts['4'] = 'https://buy.stripe.com/4gw6pK9HLdm73AI5l9';
      amounts['6'] = 'https://buy.stripe.com/dR6cO87zDgyj4EMfZO';
      amounts['10'] = 'https://buy.stripe.com/28o9BW7zD0zlc7e14V';
      amounts['15'] = 'https://buy.stripe.com/6oE8xS9HLci3efm4h8';
      amounts['25'] = 'https://buy.stripe.com/14kcO807bdm73AIfZR';
      amounts[StringConstants.custom] =
          'https://donate.stripe.com/6oE7tOg696XJ7QYcN6';
    }

    if (currency == 'AUD') {
      amounts['6'] = 'https://buy.stripe.com/aEU01m9HL0zl7QYaFD';
      amounts['9'] = 'https://buy.stripe.com/3cs4hC9HL95Rb3adRQ';
      amounts['16'] = 'https://buy.stripe.com/28o15q3jn2Ht2wE3dd';
      amounts['24'] = 'https://buy.stripe.com/6oE8xScTX95R9Z67tu';
      amounts['40'] = 'https://buy.stripe.com/28o6pK3jn1Dp0ow157';
      amounts[StringConstants.custom] =
          'https://donate.stripe.com/cN215qaLP81N4EM8x5';
    }

    if (currency == 'CAD') {
      amounts['4'] = 'https://buy.stripe.com/fZeeWg7zD0zl6MU6p8';
      amounts['6'] = 'https://buy.stripe.com/7sI5lG9HLeqb2wE14P';
      amounts['10'] = 'https://buy.stripe.com/eVa15q9HLa9Vb3abJu';
      amounts['15'] = 'https://buy.stripe.com/4gweWg07ba9V2wE00N';
      amounts['25'] = 'https://buy.stripe.com/bIYcO88DH2Ht2wEfZM';
      amounts[StringConstants.custom] =
          'https://donate.stripe.com/28o4hCdY1gyj7QY14r';
    }

    final currencySymbols = {
      'USD': '\$',
      'GBP': '£',
      'EUR': '€',
      'AUD': 'A\$',
      'INR': '₹',
      'CAD': 'C\$',
    };

    final symbol = currencySymbols[currency] ?? '\$';

    if (isMonthly) {
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
            children: amounts.entries
                .where((entry) => entry.key != StringConstants.custom)
                .toList()
                .reversed
                .map((entry) {
              final amount = entry.key;
              final url = entry.value;

              final displayText = '$symbol$amount';

              return _buildDonationAmountButton(
                context,
                displayText,
                () => _handleDonationAction(context, url),
              );
            }).toList(),
          ),
        ],
      );
    } else {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildDonationAmountButton(
            context,
            StringConstants.custom,
            () => _handleDonationAction(
                context, amounts[StringConstants.custom]!),
          ),
        ],
      );
    }
  }

  Widget _buildOtherPaymentOptions(BuildContext context) {
    return Column(
      children: [
        _buildOtherPaymentButton(
          context,
          StringConstants.payWithPaypal,
          'https://paypal.me/meditofoundation',
        ),
        const SizedBox(height: 12),
        _buildOtherPaymentButton(
          context,
          StringConstants.bankTransfer,
          'https://meditofoundation.org/about/bank-details',
        ),
      ],
    );
  }

  Widget _buildDonationAmountButton(
    BuildContext context,
    String text,
    VoidCallback onPressed,
  ) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        height: 50,
        decoration: BoxDecoration(
          color: ColorConstants.greyIsTheNewGrey,
          borderRadius: BorderRadius.circular(8),
        ),
        alignment: Alignment.center,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              text,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
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
      child: TextButton(
        onPressed: () => _handleDonationAction(context, url),
        style: TextButton.styleFrom(
          backgroundColor: ColorConstants.charcoal,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.symmetric(vertical: 16),
        ),
        child: Text(
          text,
          style: const TextStyle(
            color: ColorConstants.lightPurple,
            fontSize: 16,
          ),
        ),
      ),
    );
  }

  List<Widget> _buildPaymentMethodIcons() {
    return [
      Icon(HugeIcons.solidStandardCreditCardAccept, color: Colors.white70),
      const SizedBox(width: 16),
      Icon(FontAwesomeIcons.applePay, color: Colors.white70),
      const SizedBox(width: 16),
      Icon(FontAwesomeIcons.googlePay, color: Colors.white70),
    ];
  }

  Widget _buildFoundationInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          StringConstants.donationSecurityInfo,
          style: TextStyle(
            color: Colors.white70,
            fontSize: 12,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          StringConstants.foundationRegistrationInfo,
          style: TextStyle(
            color: Colors.white70,
            fontSize: 12,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          StringConstants.foundationContactInfo,
          style: TextStyle(
            color: Colors.white70,
            fontSize: 12,
            height: 1.5,
          ),
        ),
      ],
    );
  }

  void _handleDonationAction(BuildContext context, String url) async {
    showSnackBar(
      context,
      StringConstants.redirectingToSecurePayment,
    );

    await Future.delayed(Duration(milliseconds: 2));

    final Uri uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.inAppWebView);
    } else {
      showSnackBar(
        context,
        StringConstants.couldNotOpenDonationPage,
      );
    }
  }
}
