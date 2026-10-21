import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medito/constants/strings/shared_preference_constants.dart';
import 'package:medito/l10n/app_localizations.dart';
import 'package:medito/providers/shared_preference/shared_preference_provider.dart';
import 'package:medito/views/settings/widgets/supporter_notifications_tile.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets(
    'reminder users must explicitly enable supporter pushes and can turn them off',
    (tester) async {
      SharedPreferences.setMockInitialValues({
        SharedPreferenceConstants.dailyReminderEnabled: true,
      });
      final prefs = await SharedPreferences.getInstance();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const Scaffold(body: SupporterNotificationsTile()),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
        isFalse,
      );
      expect(find.textContaining('donation requests'), findsOneWidget);
      await tester.tap(find.byType(SwitchListTile));
      await tester.pumpAndSettle();
      expect(
        prefs.getBool(SharedPreferenceConstants.supporterCampaignPushOptIn),
        isTrue,
      );
      expect(
        tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
        isTrue,
      );
      await tester.tap(find.byType(SwitchListTile));
      await tester.pumpAndSettle();
      expect(
        prefs.getBool(SharedPreferenceConstants.supporterCampaignPushOptIn),
        isFalse,
      );
      expect(
        prefs.getBool(SharedPreferenceConstants.dailyReminderEnabled),
        isTrue,
      );
    },
  );
}
