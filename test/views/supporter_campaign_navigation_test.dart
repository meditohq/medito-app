import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medito/services/notifications/supporter_campaign_navigation.dart';

void main() {
  testWidgets('warm tap reveals the main route below a screen and a dialog', (
    tester,
  ) async {
    final navigator = GlobalKey<NavigatorState>();
    late BuildContext mainContext;
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigator,
        home: const Scaffold(body: Text('Launch route')),
      ),
    );
    navigator.currentState!.push(
      MaterialPageRoute<void>(
        builder: (context) {
          mainContext = context;
          return const Scaffold(body: Text('Home'));
        },
      ),
    );
    await tester.pumpAndSettle();
    navigator.currentState!.push(
      MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: Text('Detail screen')),
      ),
    );
    await tester.pumpAndSettle();
    showDialog<void>(
      context: mainContext,
      builder: (_) => const AlertDialog(title: Text('Dialog')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Home'), findsNothing);

    revealSupporterCampaignHome(mainContext);
    await tester.pumpAndSettle();
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Detail screen'), findsNothing);
    expect(find.text('Dialog'), findsNothing);
    // Stop at the main route, rather than popping all the way to launch.
    expect(find.text('Launch route'), findsNothing);
    expect(navigator.currentState!.canPop(), isTrue);

    revealSupporterCampaignHome(mainContext);
    await tester.pumpAndSettle();
    expect(find.text('Home'), findsOneWidget);
  });
}
