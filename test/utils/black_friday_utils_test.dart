import 'package:flutter_test/flutter_test.dart';
import 'package:medito/utils/black_friday_utils.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:medito/constants/strings/shared_preference_constants.dart';

void main() {
  group('BlackFridayUtils', () {
    group('blackFriday', () {
      test('is the day after the fourth Thursday of November', () {
        expect(BlackFridayUtils.blackFriday(2024), DateTime(2024, 11, 29));
        expect(BlackFridayUtils.blackFriday(2025), DateTime(2025, 11, 28));
        expect(BlackFridayUtils.blackFriday(2026), DateTime(2026, 11, 27));
        expect(BlackFridayUtils.blackFriday(2027), DateTime(2027, 11, 26));
        // November starting on a Thursday.
        expect(BlackFridayUtils.blackFriday(2029), DateTime(2029, 11, 23));
      });
    });

    group('isBlackFridayWeek', () {
      // 2026: Thanksgiving Nov 26, Black Friday Nov 27, Cyber Monday Nov 30.
      test('returns false before Thanksgiving', () {
        final date = DateTime(2026, 11, 25);
        expect(BlackFridayUtils.isBlackFridayWeek(date), false);
      });

      test('returns true on Thanksgiving', () {
        final date = DateTime(2026, 11, 26);
        expect(BlackFridayUtils.isBlackFridayWeek(date), true);
      });

      test('returns true on Black Friday', () {
        final date = DateTime(2026, 11, 27, 23, 59);
        expect(BlackFridayUtils.isBlackFridayWeek(date), true);
      });

      test('returns true on Cyber Monday', () {
        final date = DateTime(2026, 11, 30);
        expect(BlackFridayUtils.isBlackFridayWeek(date), true);
      });

      test('returns true a week after Black Friday', () {
        final date = DateTime(2026, 12, 4);
        expect(BlackFridayUtils.isBlackFridayWeek(date), true);
      });

      test('returns false after that', () {
        final date = DateTime(2026, 12, 5);
        expect(BlackFridayUtils.isBlackFridayWeek(date), false);
      });

      test('returns false in a different month', () {
        final date = DateTime(2026, 10, 27);
        expect(BlackFridayUtils.isBlackFridayWeek(date), false);
      });

      test('follows Black Friday from year to year', () {
        expect(
          BlackFridayUtils.isBlackFridayWeek(DateTime(2025, 11, 27)),
          true,
        );
        expect(BlackFridayUtils.isBlackFridayWeek(DateTime(2025, 12, 5)), true);
        expect(
          BlackFridayUtils.isBlackFridayWeek(DateTime(2025, 12, 6)),
          false,
        );
        expect(
          BlackFridayUtils.isBlackFridayWeek(DateTime(2027, 11, 25)),
          true,
        );
        expect(
          BlackFridayUtils.isBlackFridayWeek(DateTime(2027, 11, 24)),
          false,
        );
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

      test('returns true when dismissed this year', () async {
        await prefs.setInt(
          SharedPreferenceConstants.blackFridayDismissedYear,
          DateTime.now().year,
        );
        expect(BlackFridayUtils.isBlackFridayDismissedSync(prefs), true);
      });

      test('returns false when dismissed in an earlier year', () async {
        await prefs.setInt(
          SharedPreferenceConstants.blackFridayDismissedYear,
          DateTime.now().year - 1,
        );
        expect(BlackFridayUtils.isBlackFridayDismissedSync(prefs), false);
      });

      test('ignores the old year-less flag', () async {
        await prefs.setBool('black_friday_dismissed', true);
        expect(BlackFridayUtils.isBlackFridayDismissedSync(prefs), false);
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

      test('records the current year', () async {
        await BlackFridayUtils.dismissBlackFriday();
        expect(
          prefs.getInt(SharedPreferenceConstants.blackFridayDismissedYear),
          DateTime.now().year,
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

      test('removes the dismissal', () async {
        await prefs.setInt(
          SharedPreferenceConstants.blackFridayDismissedYear,
          DateTime.now().year,
        );
        await BlackFridayUtils.resetBlackFridayDismissal();
        expect(
          prefs.getInt(SharedPreferenceConstants.blackFridayDismissedYear),
          null,
        );
      });
    });
  });
}
