import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:intl/intl.dart';

class CurrencyInfo {
  final String code;
  final String symbol;
  final int minAmount;  // Minimum amount in the smallest currency unit
  final double exchangeRate;  // Exchange rate to USD

  CurrencyInfo(this.code, this.symbol, this.minAmount, this.exchangeRate);
}

class DonationPage extends StatefulWidget {
  const DonationPage({Key? key}) : super(key: key);

  @override
  _DonationPageState createState() => _DonationPageState();
}

class _DonationPageState extends State<DonationPage> {
  int selectedAmount = 0;
  List<int> donationAmounts = [];
  late String selectedCurrencyCode;

  final Map<String, CurrencyInfo> currencies = {
    'USD': CurrencyInfo('USD', '\$', 50, 1.0),
    'EUR': CurrencyInfo('EUR', '€', 50, 1.18),
    'GBP': CurrencyInfo('GBP', '£', 30, 1.38),
    'JPY': CurrencyInfo('JPY', '¥', 50, 0.0091),
    'INR': CurrencyInfo('INR', '₹', 50, 0.013),
    // Add more currencies as needed
  };

  @override
  void initState() {
    super.initState();
    selectedCurrencyCode = getDeviceCurrency();
    updateDonationAmounts();
    // Initialize Stripe
    Stripe.publishableKey = dotenv.env['STRIPE_PUBLISHABLE_KEY'] ?? '';
  }

  String getDeviceCurrency() {
    final String locale = Intl.getCurrentLocale();
    final NumberFormat format = NumberFormat.simpleCurrency(locale: locale);
    return format.currencyName ?? 'USD';  // Default to USD if unable to determine
  }

  void updateDonationAmounts() {
    final exchangeRate = currencies[selectedCurrencyCode]!.exchangeRate;
    final minAmount = currencies[selectedCurrencyCode]!.minAmount;

    // Base amounts in USD
    List<double> baseAmounts = [5, 10, 25, 50, 100];

    donationAmounts = baseAmounts.map((amount) {
      // Convert to selected currency
      double convertedAmount = amount / exchangeRate;

      // Round to a nice number
      int roundedAmount;
      if (convertedAmount < 10) {
        // For small amounts, round to the nearest 0.99
        roundedAmount = (convertedAmount.floor() * 100 + 99).round();
      } else if (convertedAmount < 100) {
        // For medium amounts, round to the nearest 9
        roundedAmount = (convertedAmount.floor() * 100 + 900).round();
      } else {
        // For large amounts, round to the nearest 99
        roundedAmount = (convertedAmount.floor() * 100 + 9900).round();
      }

      // Ensure the amount is not less than the minimum
      return roundedAmount < minAmount ? minAmount : roundedAmount;
    }).toSet().toList()..sort();  // Remove duplicates and sort

    // If all amounts were below minimum, add the minimum amount
    if (donationAmounts.isEmpty) {
      donationAmounts = [minAmount];
    }

    selectedAmount = donationAmounts[0];
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Donate')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DropdownButton<String>(
              value: selectedCurrencyCode,
              isExpanded: true,
              items: currencies.keys.map<DropdownMenuItem<String>>((String code) {
                return DropdownMenuItem<String>(
                  value: code,
                  child: Text('${currencies[code]!.symbol} $code'),
                );
              }).toList(),
              onChanged: (String? newValue) {
                setState(() {
                  selectedCurrencyCode = newValue!;
                  updateDonationAmounts();
                });
              },
            ),
            SizedBox(height: 20),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              alignment: WrapAlignment.center,
              children: donationAmounts.map((amount) {
                return ElevatedButton(
                  child: Text('${currencies[selectedCurrencyCode]!.symbol}${(amount / 100).toStringAsFixed(2)}'),
                  onPressed: () => setState(() => selectedAmount = amount),
                );
              }).toList(),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              child: Text('DONATE'),
              style: ElevatedButton.styleFrom(
                padding: EdgeInsets.symmetric(vertical: 16),
              ),
              onPressed: () => _handleDonation(),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleDonation() async {
    try {
      // Fetch the payment intent client secret
      final paymentIntentResult = await fetchPaymentIntentClientSecret(selectedAmount, selectedCurrencyCode);
      final clientSecret = paymentIntentResult['clientSecret'];

      // Initialize the payment sheet
      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          merchantDisplayName: 'Your Charity Name',
          paymentIntentClientSecret: clientSecret,
          style: ThemeMode.system,
          billingDetails: BillingDetails(
            email: 'example@example.com',
          ),
        ),
      );

      // Present the payment sheet
      await Stripe.instance.presentPaymentSheet();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Thank you for your ${currencies[selectedCurrencyCode]!.symbol}${(selectedAmount / 100).toStringAsFixed(2)} donation!')),
      );
    } catch (e) {
      if (e is StripeException) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error from Stripe: ${e.error.localizedMessage}')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<Map<String, dynamic>> fetchPaymentIntentClientSecret(int amount, String currency) async {
    final url = Uri.parse('${dotenv.env['BACKEND_URL']}/create-payment-intent');
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'amount': amount,
        'currency': currency.toLowerCase(),
      }),
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to create PaymentIntent');
    }
  }
}