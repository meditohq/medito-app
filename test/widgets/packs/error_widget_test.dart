import 'package:Medito/utils/strings.dart';
import 'package:Medito/widgets/packs/error_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('errorWidget should show loading_error text',
      (WidgetTester tester) async {
    var testingWidget = _wrapWidgetForTesting(ErrorPacksWidget(
      onPressed: () {},
    ));
    await tester.pumpWidget(testingWidget);

    expect(find.text(LOADING_ERROR), findsOneWidget);
    expect(find.text(TRY_AGAIN), findsOneWidget);
  });

  testWidgets('errorWidget should show snackbar when tapping the button',
      (WidgetTester tester) async {
    var testingWidget = _wrapWidgetForTesting(ErrorPacksWidget(
      onPressed: () {},
    ));
    await tester.pumpWidget(testingWidget);

    var buttons = find.byType(OutlinedButton);
    expect(buttons, findsNWidgets(2));

    // Make sure the retrying text is not showing until tapping the button
    expect(find.text(RETRYING), findsNothing);

    await tester.tap(buttons.first);
    // fast-forward the button animation
    await tester.pumpAndSettle();
    expect(find.text(RETRYING), findsOneWidget);

    // fast-forward 6001 ms for snackbar disappear, its duration is 6000ms
    await tester.pumpAndSettle(Duration(milliseconds: 6001));
    expect(find.text(RETRYING), findsNothing);
  });

  testWidgets(
      'errorWidget should call onPressed callback when pressing the button',
      (WidgetTester tester) async {
    var counterCallback = 0;
    var onPressed = () => counterCallback++;
    var testingWidget = _wrapWidgetForTesting(ErrorPacksWidget(
      onPressed: onPressed,
    ));
    await tester.pumpWidget(testingWidget);

    var buttons = find.byType(OutlinedButton);
    await tester.tap(buttons.first);
    // fast-forward the button animation
    await tester.pumpAndSettle();
    expect(counterCallback, 1);
  });
}

// Wrapping the widget with MaterialApp because it needs to know the text direction (LTR or RTL)
// and ScaffoldMessenger for showing the snackbar.
// This is only needed when testing individual widget.
// The app works without it because it is wrapped with MaterialApp at the top level.
Widget _wrapWidgetForTesting(Widget _child) {
  return MaterialApp(
    title: 'TestAppWrapper',
    home: Scaffold(
      appBar: AppBar(
        title: Text('TestAppBar'),
      ),
      body: _child,
    ),
  );
}
