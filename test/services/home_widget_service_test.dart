import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medito/services/home_widget_service.dart';

void main() {
  group('widgetStreakUnitLabels', () {
    test('uses the locale\'s translations', () {
      expect(widgetStreakUnitLabels(const Locale('de')), (
        day: 'Tag',
        days: 'Tage',
      ));
      expect(widgetStreakUnitLabels(const Locale('es')), (
        day: 'día',
        days: 'días',
      ));
      expect(widgetStreakUnitLabels(const Locale('en')), (
        day: 'day',
        days: 'days',
      ));
    });

    test('ignores the country code', () {
      expect(widgetStreakUnitLabels(const Locale('de', 'AT')).days, 'Tage');
    });

    test('falls back to English for null or unsupported locales', () {
      expect(widgetStreakUnitLabels(null), (day: 'day', days: 'days'));
      expect(widgetStreakUnitLabels(const Locale('fr')), (
        day: 'day',
        days: 'days',
      ));
    });
  });

  group('widgetStrings', () {
    test('keeps the tokens the widgets fill in', () {
      final strings = widgetStrings(const Locale('en'));
      expect(strings['widget_streak_summary'], 'Meditation streak: {value}');
      expect(
        strings['widget_recent_days'],
        'Meditated on {done} of the last {total} days',
      );
      expect(strings['widget_up_next_progress'], '{completed} of {total}');
    });

    test('uses the locale\'s translations', () {
      final strings = widgetStrings(const Locale('de'));
      expect(
        strings['widget_consistency_summary'],
        'Beständigkeitswert: {value}',
      );
      expect(strings['widget_start_here'], 'Hier beginnen');
    });

    test('falls back to English for null or unsupported locales', () {
      expect(widgetStrings(null), widgetStrings(const Locale('en')));
      expect(
        widgetStrings(const Locale('fr')),
        widgetStrings(const Locale('en')),
      );
    });
  });
}
