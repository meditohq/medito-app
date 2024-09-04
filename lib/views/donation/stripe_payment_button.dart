import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';

import 'donation_page.dart';

class StripePaymentButton extends StatelessWidget {
  const StripePaymentButton({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      child: const Text('Donate with Stripe'),
      onPressed: () {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (context) => const DonationPage()),
        );
      },
    );
  }
}
