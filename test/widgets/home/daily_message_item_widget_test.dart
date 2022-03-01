import 'package:Medito/network/home/daily_message_response.dart';
import 'package:Medito/widgets/home/daily_message_item_widget.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_test/flutter_test.dart';

import '../WidgetTestUtil.dart';

void main() {
  var testData;

  setUp(() {
    testData = DailyMessageResponse(data: Data(title: 'test_title', body: 'test_body'));
  });

  testWidgets('dailyMessageItemWidget should have title and MarkdownBody',
      (WidgetTester tester) async {
    var testingWidget = WidgetTestUtil.wrapWidgetForTesting(
        child: DailyMessageItemWidget(data: testData));

    await tester.pumpWidget(testingWidget);

    var title = find.text('test_title'.toUpperCase());
    expect(title, findsOneWidget);

    var body = find.byType(MarkdownBody);
    expect(body, findsOneWidget);
  });

}
