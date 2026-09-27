import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medito/widgets/inputs/medito_text_field.dart';

void main() {
  testWidgets('keeps focus while errorText appears and clears', (
    tester,
  ) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);

    // Mirrors the sign-in email field: error shows once text is non-empty
    // but invalid, and clears once it validates.
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              final text = controller.text;
              return MeditoTextField(
                controller: controller,
                hintText: 'Email',
                errorText: text.isNotEmpty && !text.contains('@')
                    ? 'Invalid Email.'
                    : null,
                onChanged: (_) => setState(() {}),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.byType(TextField));
    await tester.pump();
    final editable = tester.state(find.byType(EditableText));
    expect(tester.testTextInput.isVisible, isTrue);

    await tester.enterText(find.byType(TextField), 't');
    await tester.pump();
    expect(find.text('Invalid Email.'), findsOneWidget);
    expect(tester.state(find.byType(EditableText)), same(editable));
    expect(tester.testTextInput.isVisible, isTrue);

    await tester.enterText(find.byType(TextField), 't@x');
    await tester.pump();
    expect(find.text('Invalid Email.'), findsNothing);
    expect(tester.state(find.byType(EditableText)), same(editable));
    expect(tester.testTextInput.isVisible, isTrue);
  });
}
