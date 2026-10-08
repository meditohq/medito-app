import 'package:flutter_test/flutter_test.dart';
import 'package:home_widget/home_widget.dart';
import 'package:medito/services/installed_widgets_service.dart';

void main() {
  group('homeWidgetsPropertyValue', () {
    test('no widgets reports none', () {
      expect(homeWidgetsPropertyValue([]), 'none');
    });

    test('maps iOS widget kinds, sorted and de-duplicated', () {
      final widgets = [
        HomeWidgetInfo(iOSKind: 'UpNextWidget', iOSFamily: 'systemSmall'),
        HomeWidgetInfo(iOSKind: 'StreakWidget', iOSFamily: 'systemSmall'),
        HomeWidgetInfo(iOSKind: 'StreakWidget', iOSFamily: 'systemMedium'),
      ];
      expect(homeWidgetsPropertyValue(widgets), 'streak,up_next');
    });

    test('maps Android receivers, including the streak MeditationWidget', () {
      final widgets = [
        HomeWidgetInfo(
          androidWidgetId: 1,
          androidClassName: '.widget.MeditationWidgetReceiver',
        ),
        HomeWidgetInfo(
          androidWidgetId: 2,
          androidClassName: '.widget.ConsistencyWidgetReceiver',
        ),
        HomeWidgetInfo(
          androidWidgetId: 3,
          androidClassName: '.widget.UpNextWidgetReceiver',
        ),
      ];
      expect(homeWidgetsPropertyValue(widgets), 'consistency,streak,up_next');
    });

    test('unknown widgets report other', () {
      final widgets = [HomeWidgetInfo(iOSKind: 'SomethingNew')];
      expect(homeWidgetsPropertyValue(widgets), 'other');
    });
  });
}
