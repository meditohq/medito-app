// The Settings watch-install row must only appear while a watch is paired
// without the Medito watch app, and vanish (not leave a blank row) otherwise.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medito/l10n/app_localizations.dart';
import 'package:medito/services/watch_presence_service.dart';
import 'package:medito/views/home/widgets/bottom_sheet/row_item_widget.dart';
import 'package:medito/views/settings/widgets/watch_install_tile.dart';

void main() {
  Future<void> pump(WidgetTester tester, {required bool prompt}) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          watchInstallPromptProvider.overrideWith((ref) async => prompt),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: WatchInstallTile()),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shows the row when a watch lacks the app', (tester) async {
    await pump(tester, prompt: true);
    expect(find.byType(RowItemWidget), findsOneWidget);
    expect(find.textContaining('Medito on your watch', findRichText: true), findsOneWidget);
  });

  testWidgets('renders nothing otherwise', (tester) async {
    await pump(tester, prompt: false);
    expect(find.byType(RowItemWidget), findsNothing);
  });
}
