import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medito/services/account/account_service.dart';
import 'package:medito/views/previews/preview_support.dart';
import 'package:medito/views/settings/delete_account_screen.dart';

class _PendingAccountService implements AccountService {
  final result = Completer<void>();
  int calls = 0;

  @override
  Future<void> deleteAccount({DeleteAccountReason? reason, String? details}) {
    calls++;
    return result.future;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late _PendingAccountService service;

  // The fake must be created inside the test (not setUp): its Completer has
  // to live in the test's fake-async zone or completing it never runs.
  Future<void> openDeleteScreen(WidgetTester tester) async {
    service = _PendingAccountService();
    await tester.pumpWidget(
      PreviewShell(
        prefs: const {},
        email: 'user@example.com',
        overrides: [accountServiceProvider.overrideWithValue(service)],
        child: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const DeleteAccountScreen(),
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  Future<void> tapDelete(WidgetTester tester) async {
    final button = find.text('Delete my account');
    await tester.scrollUntilVisible(
      button,
      200,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(button);
    await tester.pump();
  }

  // pumpAndSettle never settles while the button spinner runs.
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 300));
    }
  }

  testWidgets('system back is blocked while a delete is in flight', (
    tester,
  ) async {
    await openDeleteScreen(tester);
    await tapDelete(tester);

    await tester.binding.handlePopRoute();
    await settle(tester);

    expect(find.byType(DeleteAccountScreen), findsOneWidget);

    service.result.complete();
    await settle(tester);

    expect(find.byType(AccountDeletedScreen), findsOneWidget);
  });

  testWidgets('a second tap does not send a second delete', (tester) async {
    await openDeleteScreen(tester);
    await tapDelete(tester);
    await tester.tap(find.text('Delete my account'), warnIfMissed: false);
    await tester.pump();

    expect(service.calls, 1);
    service.result.complete();
    await settle(tester);
  });

  testWidgets('an unconfirmed outcome keeps the user on the screen', (
    tester,
  ) async {
    await openDeleteScreen(tester);
    await tapDelete(tester);

    service.result.completeError(const AccountDeletionUnconfirmed('timeout'));
    await settle(tester);

    expect(find.byType(DeleteAccountScreen), findsOneWidget);
    expect(find.byType(AccountDeletedScreen), findsNothing);
    // The button is enabled again so the user can retry.
    await tapDelete(tester);
    expect(service.calls, 2);
  });
}
