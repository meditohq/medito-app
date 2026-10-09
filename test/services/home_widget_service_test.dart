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
}
