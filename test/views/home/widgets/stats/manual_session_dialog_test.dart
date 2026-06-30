import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medito/l10n/app_localizations.dart';
import 'package:medito/views/home/widgets/bottom_sheet/stats/manual_session_dialog.dart';

void main() {
  testWidgets('Add button submits on a small screen with the keyboard up '
      '(regression: overflowing button taps fell through to the barrier)', (
    tester,
  ) async {
    // iPhone SE-class viewport with the number pad open. Before the dialog
    // body was scrollable, the Cancel/Add row painted below the dialog's
    // bounds here, so tapping Add hit the modal barrier and dismissed the
    // dialog with null — silently discarding the session.
    tester.view.physicalSize = const Size(320 * 2, 568 * 2);
    tester.view.devicePixelRatio = 2.0;
    tester.view.viewInsets = const FakeViewPadding(bottom: 260 * 2);
    addTearDown(tester.view.reset);

    ManualSessionResult? result;
    var dialogClosed = false;

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: ElevatedButton(
                onPressed: () async {
                  result = await showDialog<ManualSessionResult>(
                    context: context,
                    barrierDismissible: false,
                    builder: (_) => ManualSessionDialog(
                      // Past date so the future-session guard never disables
                      // the Add button.
                      selectedDate: DateTime(2020, 1, 1),
                      bulkPreviewBuilder: (start, end) =>
                          const BulkSessionPreview(
                            dayCount: 1,
                            newSessionsCount: 1,
                            currentStreak: 0,
                            projectedStreak: 1,
                          ),
                    ),
                  );
                  dialogClosed = true;
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    await tester.enterText(find.byType(TextField).first, '10');
    await tester.pump();

    final addButton = find.text(l10n.add);
    expect(addButton, findsOneWidget);

    // The fix: the dialog body scrolls, so the button can be brought into
    // the dialog's bounds and genuinely tapped.
    await tester.ensureVisible(addButton);
    await tester.pumpAndSettle();
    await tester.tap(addButton);
    await tester.pumpAndSettle();

    expect(dialogClosed, isTrue);
    expect(result, isA<ManualSessionSingleResult>());
    expect((result as ManualSessionSingleResult).duration, 10);
  });
}
