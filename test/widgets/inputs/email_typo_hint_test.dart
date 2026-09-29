import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medito/l10n/app_localizations.dart';
import 'package:medito/widgets/inputs/email_typo_hint.dart';

void main() {
  Future<TextEditingController> pump(
    WidgetTester tester, {
    VoidCallback? onAccepted,
  }) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: EmailTypoHint(controller: controller, onAccepted: onAccepted),
        ),
      ),
    );
    return controller;
  }

  testWidgets('hidden until the domain looks mistyped', (tester) async {
    final controller = await pump(tester);
    expect(find.byKey(emailTypoHintKey), findsNothing);

    controller.text = 'mike@gmail.com';
    await tester.pump();
    expect(find.byKey(emailTypoHintKey), findsNothing);

    controller.text = 'mike@gmil.con';
    await tester.pump();
    expect(find.text('Did you mean mike@gmail.com?'), findsOneWidget);
  });

  testWidgets('tap applies the fix and hides the hint', (tester) async {
    var accepted = 0;
    final controller = await pump(tester, onAccepted: () => accepted++);
    controller.text = 'mike@gmail.con';
    await tester.pump();

    await tester.tap(find.byKey(emailTypoHintKey));
    await tester.pump();

    expect(controller.text, 'mike@gmail.com');
    expect(controller.selection.baseOffset, 'mike@gmail.com'.length);
    expect(accepted, 1);
    expect(find.byKey(emailTypoHintKey), findsNothing);
  });

  group('EmailTypoConfirmation', () {
    late EmailTypoConfirmation confirmation;
    late TextEditingController controller;
    late BuildContext context;

    Future<void> pumpHost(WidgetTester tester, String text) async {
      confirmation = EmailTypoConfirmation();
      controller = TextEditingController(text: text);
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (c) {
              context = c;
              return const Scaffold();
            },
          ),
        ),
      );
    }

    Future<bool> confirm(WidgetTester tester, {String? tap}) async {
      final result = confirmation.confirm(context, controller);
      await tester.pumpAndSettle();
      if (tap != null) {
        await tester.tap(find.text(tap));
        await tester.pumpAndSettle();
      }
      return result;
    }

    testWidgets('no typo: goes ahead without a dialog', (tester) async {
      await pumpHost(tester, 'mike@gmail.com');
      expect(await confirm(tester), isTrue);
      expect(find.byKey(emailTypoDialogKey), findsNothing);
    });

    testWidgets('"Use this" applies the fix and goes ahead', (tester) async {
      await pumpHost(tester, 'mike@gmil.con');
      final future = confirmation.confirm(context, controller);
      await tester.pumpAndSettle();
      expect(
        find.text('You typed mike@gmil.con.\nDid you mean mike@gmail.com?'),
        findsOneWidget,
      );
      await tester.tap(find.text('Use this'));
      await tester.pumpAndSettle();
      expect(await future, isTrue);
      expect(controller.text, 'mike@gmail.com');
    });

    testWidgets('"Keep mine" goes ahead and is not asked again', (
      tester,
    ) async {
      await pumpHost(tester, 'mike@gmil.com');
      expect(await confirm(tester, tap: 'Keep mine'), isTrue);
      expect(controller.text, 'mike@gmil.com');

      expect(await confirm(tester), isTrue);
      expect(find.byKey(emailTypoDialogKey), findsNothing);
    });

    testWidgets('dismissing keeps the user on the form', (tester) async {
      await pumpHost(tester, 'mike@gmil.com');
      final future = confirmation.confirm(context, controller);
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(4, 4));
      await tester.pumpAndSettle();
      expect(await future, isFalse);
      expect(controller.text, 'mike@gmil.com');
    });
  });
}
