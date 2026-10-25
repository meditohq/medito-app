import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medito/l10n/app_localizations.dart';
import 'package:medito/views/pack/widgets/pack_complete_badge.dart';
import 'package:medito/widgets/pack_card_widget.dart';

void main() {
  Future<void> pump(
    WidgetTester tester, {
    required bool completed,
    VoidCallback? onTap,
  }) {
    return tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: PackCardWidget(
            title: 'Sleep',
            subTitle: 'Rest well',
            isCompleted: completed,
            onTap: onTap,
          ),
        ),
      ),
    );
  }

  testWidgets('shows the tick only when completed', (tester) async {
    await pump(tester, completed: false);
    expect(find.byType(PackCompleteBadge), findsNothing);

    await pump(tester, completed: true);
    expect(find.byType(PackCompleteBadge), findsOneWidget);
  });

  testWidgets('reads as one button that includes Completed', (tester) async {
    final handle = tester.ensureSemantics();
    await pump(tester, completed: true, onTap: () {});

    // The badge sits outside the InkWell; it must merge into the card.
    final node = tester.getSemantics(find.byType(PackCompleteBadge));
    expect(node, isSemantics(isButton: true, hasTapAction: true));
    expect(node.label, allOf(contains('Sleep'), contains('Completed')));
    handle.dispose();
  });

  testWidgets('a tap on the tick still opens the pack', (tester) async {
    var taps = 0;
    await pump(tester, completed: true, onTap: () => taps++);

    await tester.tap(find.byType(PackCompleteBadge));
    expect(taps, 1);
  });
}
