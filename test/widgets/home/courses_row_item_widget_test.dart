import 'package:Medito/network/home/courses_response.dart';
import 'package:Medito/widgets/home/courses_row_item_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../WidgetTestUtil.dart';

void main() {
  var testData;

  setUp(() {
    testData = Data(
      title: 'test_title',
      subtitle: 'test_subtitle',
      backgroundImage: 'test_backgroundImage',
      type: 'test_type',
      id: 'test_id',
      cover: 'test_cover',
      colorPrimary: Colors.black.toString(),
    );
  });

  testWidgets(
      'coursesRowItemWidget should execute onTap action on selected waiting item',
          (WidgetTester tester) async {
        var testingWidget = WidgetTestUtil.wrapWidgetForTesting(
            child: CoursesRowItemWidget.waiting());
        await tester.pumpWidget(testingWidget);
        await tester.tap(find.byType(CoursesRowItemWidget));
        await tester.pumpAndSettle();
      });

  testWidgets(
      'coursesRowItemWidget should not throw when data and onTap are null',
          (WidgetTester tester) async {
        var testingWidget = WidgetTestUtil.wrapWidgetForTesting(
            child: CoursesRowItemWidget(data: null, onTap: null));
        await tester.pumpWidget(testingWidget);
        await tester.tap(find.byType(CoursesRowItemWidget));
        await tester.pumpAndSettle();
      });

  testWidgets(
      'coursesRowItemWidget should not throw when tapping on loading widget',
          (WidgetTester tester) async {
        var testingWidget = WidgetTestUtil.wrapWidgetForTesting(
            child: CoursesRowItemWidget.waiting());
        await tester.pumpWidget(testingWidget);
        await tester.tap(find.byType(CoursesRowItemWidget));
        await tester.pumpAndSettle();
      });
}
