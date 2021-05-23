import 'package:Medito/network/home/courses_response.dart';
import 'package:Medito/widgets/home/courses_row_item_widget.dart';
import 'package:Medito/widgets/home/daily_message_item_widget.dart';
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

  testWidgets('coursesRowItemWidget should have title and subtitle',
          (WidgetTester tester) async {
        var testingWidget = WidgetTestUtil.wrapWidgetForTesting(
            child: CoursesRowItemWidget(data: testData));

        await tester.pumpWidget(testingWidget);

        var title = find.text('test_title');
        expect(title, findsOneWidget);

        var subtitle = find.text('test_subtitle');
        expect(subtitle, findsOneWidget);
      });

  testWidgets(
      'coursesRowItemWidget should execute onTap action on selected item',
          (WidgetTester tester) async {
        var onTapData = {};
        var testingWidget = WidgetTestUtil.wrapWidgetForTesting(
            child: CoursesRowItemWidget(
              data: testData,
              onTap: (type, id) {
                onTapData['type'] = type;
                onTapData['id'] = id;
              },
            ));
        await tester.pumpWidget(testingWidget);
        await tester.tap(find.byType(CoursesRowItemWidget));
        await tester.pumpAndSettle();
        expect(onTapData['type'], 'test_type');
        expect(onTapData['id'], 'test_id');
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

  testWidgets('coursesRowItemWidget should not throw when onTap is null',
          (WidgetTester tester) async {
        var testingWidget = WidgetTestUtil.wrapWidgetForTesting(
            child: CoursesRowItemWidget(data: testData, onTap: null));
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
