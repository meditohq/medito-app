import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:purchases_ui_flutter/purchases_ui_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SubscriptionPage extends ConsumerWidget {
  const SubscriptionPage({super.key});

  final methodChannel = const MethodChannel('revenue_cat_debug_view');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            OutlinedButton(
                  onPressed: () => presentPaywall(),
                  child: const Text("Present Paywall"),
                ),
            OutlinedButton(
                  onPressed: () async {
                    try {
                      await methodChannel.invokeMethod('showRevenueCatNativeDebugView');
                    } catch (e) {
                      print('Error showing SwiftUI view: $e');
                    }
                  },
                  child: const Text("Launch Debug"),
                ),
          ],
        ),
      ),
    );
  }

void presentPaywall() async {
    final paywallResult = await RevenueCatUI.presentPaywall();
    print('Paywall result: $paywallResult');
}

void presentPaywallIfNeeded() async {
    final paywallResult = await RevenueCatUI.presentPaywallIfNeeded("pro");
    print('Paywall result: $paywallResult');
}
}