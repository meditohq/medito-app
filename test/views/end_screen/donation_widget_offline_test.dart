import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medito/constants/strings/shared_preference_constants.dart';
import 'package:medito/exceptions/app_error.dart';
import 'package:medito/models/events/donation/donation_page_model.dart';
import 'package:medito/providers/donation/donation_page_provider.dart';
import 'package:medito/providers/stripe/payment_service_provider.dart';
import 'package:medito/views/end_screen/widgets/donation_thank_you_card.dart';
import 'package:medito/views/end_screen/widgets/donation_widget.dart';
import 'package:medito/views/end_screen/widgets/feedback_widget.dart';
import 'package:medito/views/previews/preview_support.dart';

void main() {
  Future<void> pump(
    WidgetTester tester, {
    required Future<DonationPageModel> Function() load,
    Map<String, Object> prefs = const {},
  }) async {
    await tester.pumpWidget(
      PreviewShell(
        locale: const Locale('en'),
        prefs: prefs,
        overrides: [
          fetchDonationPageProvider.overrideWith((ref) => load()),
          endScreenPaywallConfigProvider.overrideWith(
            (ref) async => throw const NetworkConnectionError(),
          ),
        ],
        child: const Scaffold(
          body: SingleChildScrollView(child: DonationWidget()),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 4));
  }

  testWidgets('feedback works while donation copy is loading', (tester) async {
    final pending = Completer<DonationPageModel>();
    await pump(tester, load: () => pending.future);
    expect(find.byType(FeedbackWidget), findsOneWidget);
    await tester.tap(find.text('😐'));
    await tester.pump();
    expect(find.textContaining('Thanks for sharing'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('offline donation load shows local copy and feedback', (
    tester,
  ) async {
    await pump(tester, load: () async => throw const NetworkConnectionError());
    expect(find.text('Support Medito'), findsOneWidget);
    expect(find.byType(ElevatedButton), findsOneWidget);
    expect(find.byType(FeedbackWidget), findsOneWidget);
    expect(find.text('No internet connection'), findsNothing);
  });

  testWidgets('donor thank-you does not wait for donation copy', (
    tester,
  ) async {
    final pending = Completer<DonationPageModel>();
    final now = DateTime.now();
    await pump(
      tester,
      load: () => pending.future,
      prefs: {
        SharedPreferenceConstants.lastSuccessfulDonationAtMs:
            now.millisecondsSinceEpoch,
        SharedPreferenceConstants.donationAskSnoozedUntilMs: now
            .add(const Duration(days: 30))
            .millisecondsSinceEpoch,
      },
    );
    expect(find.byType(DonationThankYouCard), findsOneWidget);
    expect(find.byType(FeedbackWidget), findsOneWidget);
  });
}
