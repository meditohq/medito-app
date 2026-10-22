import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medito/constants/strings/shared_preference_constants.dart';
import 'package:medito/l10n/app_localizations.dart';
import 'package:medito/models/home/home_model.dart';
import 'package:medito/providers/donation/supporter_appeal_experiment.dart';
import 'package:medito/providers/donation/supporter_appeal_provider.dart';
import 'package:medito/providers/home/announcement_provider.dart';
import 'package:medito/providers/home/home_provider.dart';
import 'package:medito/providers/shared_preference/shared_preference_provider.dart';
import 'package:medito/views/home/home_view.dart';
import 'package:medito/views/home/widgets/header/home_hero.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets(
    'independent requests start while the Home feed is still loading',
    (tester) async {
      SharedPreferences.setMockInitialValues({
        SharedPreferenceConstants.analyticsFirebaseEnabled: false,
      });
      final prefs = await SharedPreferences.getInstance();
      final feed = Completer<HomeModel>();
      final assignment = Completer<AppealAssignment?>();
      var heroStarted = false,
          announcementStarted = false,
          campaignStarted = false;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            fetchHomeProvider.overrideWith((ref) => feed.future),
            homeHeroCoverProvider.overrideWith((ref) {
              heroStarted = true;
              return null;
            }),
            fetchLatestAnnouncementProvider.overrideWith((ref) async {
              announcementStarted = true;
              return null;
            }),
            supporterAppealProvider.overrideWith((ref) {
              campaignStarted = true;
              return assignment.future;
            }),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const HomeView(),
          ),
        ),
      );
      expect(feed.isCompleted, isFalse);
      expect(heroStarted, isTrue);
      expect(announcementStarted, isTrue);
      expect(campaignStarted, isTrue);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 3));
    },
  );
}
