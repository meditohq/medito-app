import 'package:flutter_test/flutter_test.dart';
import 'package:medito/utils/black_friday_utils.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:medito/constants/strings/shared_preference_constants.dart';

void main() {
  group('BlackFridayUtils', () {
    group('isBlackFridayWeek', () {
      test('returns false before Black Friday week', () {
        final date = DateTime(2024, 11, 26); // Nov 26, day before
        expect(BlackFridayUtils.isBlackFridayWeek(date), false);
      });

      test('returns true on day before Black Friday', () {
        final date = DateTime(2024, 11, 27); // Nov 27, day before Black Friday
        expect(BlackFridayUtils.isBlackFridayWeek(date), true);
      });

      test('returns true on Black Friday start day', () {
        final date = DateTime(2024, 11, 28); // Nov 28, Black Friday
        expect(BlackFridayUtils.isBlackFridayWeek(date), true);
      });

      test('returns true during Black Friday week', () {
        final date = DateTime(2024, 11, 30); // Nov 30, mid-week
        expect(BlackFridayUtils.isBlackFridayWeek(date), true);
      });

      test('returns true on last day of Black Friday week', () {
        final date = DateTime(2024, 12, 5); // Dec 5, last day (28 + 7 days)
        expect(BlackFridayUtils.isBlackFridayWeek(date), true);
      });

      test('returns false after Black Friday week', () {
        final date = DateTime(2024, 12, 6); // Dec 6, day after
        expect(BlackFridayUtils.isBlackFridayWeek(date), false);
      });

      test('returns false in different month', () {
        final date = DateTime(2024, 10, 28); // October
        expect(BlackFridayUtils.isBlackFridayWeek(date), false);
      });

      test('works for different years', () {
        final date2025 = DateTime(2025, 11, 28);
        final date2026 = DateTime(2026, 11, 28);
        expect(BlackFridayUtils.isBlackFridayWeek(date2025), true);
        expect(BlackFridayUtils.isBlackFridayWeek(date2026), true);
      });
    });

    group('isBlackFridayDismissedSync', () {
      late SharedPreferences prefs;

      setUp(() async {
        SharedPreferences.setMockInitialValues({});
        prefs = await SharedPreferences.getInstance();
      });

      tearDown(() async {
        await prefs.clear();
      });

      test('returns false when not dismissed', () {
        expect(BlackFridayUtils.isBlackFridayDismissedSync(prefs), false);
      });

      test('returns true when dismissed', () async {
        await prefs.setBool(
          SharedPreferenceConstants.blackFridayDismissed,
          true,
        );
        expect(BlackFridayUtils.isBlackFridayDismissedSync(prefs), true);
      });
    });

    group('dismissBlackFriday', () {
      late SharedPreferences prefs;

      setUp(() async {
        SharedPreferences.setMockInitialValues({});
        prefs = await SharedPreferences.getInstance();
      });

      tearDown(() async {
        await prefs.clear();
      });

      test('sets dismissal flag', () async {
        await BlackFridayUtils.dismissBlackFriday();
        expect(
          prefs.getBool(SharedPreferenceConstants.blackFridayDismissed),
          true,
        );
      });
    });

    group('resetBlackFridayDismissal', () {
      late SharedPreferences prefs;

      setUp(() async {
        SharedPreferences.setMockInitialValues({});
        prefs = await SharedPreferences.getInstance();
      });

      tearDown(() async {
        await prefs.clear();
      });

      test('removes dismissal flag', () async {
        await prefs.setBool(
          SharedPreferenceConstants.blackFridayDismissed,
          true,
        );
        await BlackFridayUtils.resetBlackFridayDismissal();
        expect(
          prefs.getBool(SharedPreferenceConstants.blackFridayDismissed),
          null,
        );
      });
    });
  });
}
