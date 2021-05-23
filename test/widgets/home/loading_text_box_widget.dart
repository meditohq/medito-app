import 'package:Medito/widgets/home/loading_text_box_widget.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('loadingTextBox should have configurable height',
      (WidgetTester tester) async {
    var loadingTextBox = LoadingTextBoxWidget(height: 10);
    await tester.pumpWidget(loadingTextBox);
    expect(loadingTextBox.height, 10);
  });

  testWidgets('loadingTextBox should have clipRRect and Container',
      (WidgetTester tester) async {
    var loadingTextBox = LoadingTextBoxWidget(height: 10);
    await tester.pumpWidget(loadingTextBox);
    var clipRRect = find.byType(ClipRRect);
    var container = find.byType(Container);
    expect(clipRRect, findsOneWidget);
    expect(container, findsOneWidget);
  });
}
