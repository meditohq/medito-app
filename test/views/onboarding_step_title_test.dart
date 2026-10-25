import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medito/widgets/onboarding/onboarding_step_title.dart';

void main() {
  late List<String> announced;

  setUp(() {
    announced = [];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockDecodedMessageHandler<dynamic>(SystemChannels.accessibility, (
          message,
        ) async {
          final map = message as Map<dynamic, dynamic>;
          if (map['type'] == 'announce') {
            announced.add((map['data'] as Map<dynamic, dynamic>)['message']);
          }
          return null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockDecodedMessageHandler<dynamic>(
          SystemChannels.accessibility,
          null,
        );
  });

  Future<void> pump(WidgetTester tester, Widget child) async {
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: child)));
    await tester.pump();
  }

  testWidgets('is a heading', (tester) async {
    final handle = tester.ensureSemantics();
    await pump(tester, const OnboardingStepTitle('Title'));
    expect(
      tester.getSemantics(find.text('Title')),
      isSemantics(label: 'Title', isHeader: true),
    );
    handle.dispose();
  });

  testWidgets('the first page stays quiet', (tester) async {
    await pump(tester, const OnboardingStepTitle('Title'));
    expect(announced, isEmpty);
  });

  testWidgets('a paged-to step announces its title and position once', (
    tester,
  ) async {
    await pump(
      tester,
      const OnboardingStepAnnouncement(
        position: 'Step 2 of 3',
        child: OnboardingStepTitle('Reminders'),
      ),
    );
    expect(announced, ['Reminders. Step 2 of 3']);

    // Rebuilds don't repeat it.
    await pump(
      tester,
      const OnboardingStepAnnouncement(
        position: 'Step 2 of 3',
        child: OnboardingStepTitle('Reminders'),
      ),
    );
    expect(announced, ['Reminders. Step 2 of 3']);
  });
}
