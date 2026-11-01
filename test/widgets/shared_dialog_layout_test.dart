import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medito/constants/theme/app_theme.dart';
import 'package:medito/l10n/app_localizations.dart';
import 'package:medito/views/home/widgets/bottom_sheet/stats/edit_session_dialog.dart';
import 'package:medito/views/settings/delete_account_screen.dart';
import 'package:medito/views/settings/widgets/day_boundary_offset_dialog.dart';
import 'package:medito/widgets/dialogs/dialogs.dart';

void main() {
  setUpAll(() async {
    await (FontLoader('Google Sans')..addFont(
          rootBundle.load('assets/fonts/google-sans/GoogleSans-Regular.ttf'),
        ))
        .load();
  });
  final dialogs = <String, Widget Function()>{
    'edit session': () =>
        EditSessionDialog(initialDate: DateTime(2020, 1, 1, 12)),
    'day boundary': () => const DayBoundaryOffsetDialog(currentHours: 0),
    'delete account': () => const DeleteAccountConfirmationDialog(),
  };
  for (final mode in [ThemeMode.dark, ThemeMode.light]) {
    for (final scale in [1.0, 2.0]) {
      for (final entry in dialogs.entries) {
        testWidgets(
          '${entry.key} keeps actions reachable at $scale text in $mode',
          (tester) async {
            tester.view.physicalSize = const Size(320, 568);
            tester.view.devicePixelRatio = 1;
            addTearDown(tester.view.resetPhysicalSize);
            addTearDown(tester.view.resetDevicePixelRatio);
            await tester.pumpWidget(
              Builder(
                builder: (context) => MaterialApp(
                  theme: appTheme(context, mode),
                  localizationsDelegates:
                      AppLocalizations.localizationsDelegates,
                  supportedLocales: AppLocalizations.supportedLocales,
                  builder: (context, child) => MediaQuery(
                    data: MediaQuery.of(
                      context,
                    ).copyWith(textScaler: TextScaler.linear(scale)),
                    child: child!,
                  ),
                  home: Scaffold(
                    body: Builder(
                      builder: (context) => TextButton(
                        child: const Text('Open dialog'),
                        onPressed: () => showDialog<void>(
                          context: context,
                          builder: (_) => entry.value(),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
            await tester.tap(find.text('Open dialog'));
            await tester.pumpAndSettle();
            expect(find.byType(MeditoDialogTitle), findsOneWidget);
            expect(find.byType(MeditoDialogBody), findsWidgets);
            expect(tester.takeException(), isNull);
            final cancel = find.widgetWithText(
              MeditoDialogSecondaryButton,
              'Cancel',
            );
            await tester.ensureVisible(cancel);
            await tester.pumpAndSettle();
            expect(cancel.hitTestable(), findsOneWidget);
            await tester.tap(cancel);
            await tester.pumpAndSettle();
            expect(find.byType(MeditoDialog), findsNothing);
            expect(tester.takeException(), isNull);
          },
        );
      }
    }
  }
}
