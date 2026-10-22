import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medito/l10n/app_localizations.dart';
import 'package:medito/models/local_all_stats.dart';
import 'package:medito/models/local_audio_completed.dart';
import 'package:medito/providers/donation/supporter_appeal_experiment.dart';
import 'package:medito/providers/shared_preference/shared_preference_provider.dart';
import 'package:medito/views/home/widgets/announcement/supporter_appeal_card.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets(
    'hidden Home does not count a view; visible card respects dismissal',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final now = DateTime.now();
      final experiment = SupporterAppealExperiment(prefs);
      final seed = List.generate(
        100,
        (i) => i,
      ).firstWhere((i) => Random(i).nextInt(3) == 1);
      await experiment.enroll(
        stats: LocalAllStats.empty().copyWith(
          audioCompleted: [
            for (final days in [60, 10, 1])
              LocalAudioCompleted(
                timestamp: now
                    .subtract(Duration(days: days))
                    .millisecondsSinceEpoch,
                id: '$days',
              ),
          ],
        ),
        now: now,
        notificationsAllowed: false,
        random: Random(seed),
      );
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      Widget app(int index) => ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
          ],
          supportedLocales: const [Locale('en')],
          home: Scaffold(
            body: IndexedStack(
              index: index,
              children: const [SupporterAppealCard(), SizedBox()],
            ),
          ),
        ),
      );
      await tester.pumpWidget(app(1));
      await tester.pumpAndSettle();
      expect(prefs.getBool(SupporterAppealExperiment.shownKey), isNull);
      await tester.pumpWidget(app(0));
      await tester.pumpAndSettle();
      expect(prefs.getBool(SupporterAppealExperiment.shownKey), isTrue);
      expect(find.text('Donate now'), findsOneWidget);
      expect(find.text('I already support Medito'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Dismiss'));
      await tester.pumpAndSettle();
      expect(prefs.getBool(SupporterAppealExperiment.dismissedKey), isTrue);
      expect(experiment.showCard(DateTime.now()), isFalse);
    },
  );
}
