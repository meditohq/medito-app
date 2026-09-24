import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medito/constants/config_constants.dart';
import 'package:medito/constants/strings/shared_preference_constants.dart';
import 'package:medito/constants/types/type_constants.dart';
import 'package:medito/l10n/app_localizations.dart';
import 'package:medito/models/models.dart';
import 'package:medito/providers/home/up_next_provider.dart';
import 'package:medito/providers/pack/pack_provider.dart';
import 'package:medito/providers/shared_preference/shared_preference_provider.dart';
import 'package:medito/scaffold_messenger_key.dart';
import 'package:medito/views/pack/widgets/pack_path_button.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakePack extends Pack {
  _FakePack(this.model);
  final PackModel model;

  @override
  AsyncValue<PackModel> build({required String packId}) => AsyncData(model);
}

PackModel _pack(String id, String title, {int tracks = 3, int done = 1}) {
  return PackModel(
    id: id,
    title: title,
    items: List.generate(
      tracks,
      (i) => PackItemsModel(
        type: TypeConstants.track,
        id: '$id-$i',
        title: 'Session $i',
        path: '/tracks/$id-$i',
        isCompleted: i < done,
      ),
    ),
  );
}

void main() {
  late SharedPreferences prefs;
  late AppLocalizations l10n;

  final basics = _pack(ConfigConstants.basicsPackId, 'Basics');
  final sleep = _pack('sleep', 'Sleep', tracks: 7, done: 3);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    l10n = await AppLocalizations.delegate.load(const Locale('en'));
  });

  Future<void> pump(WidgetTester tester, PackModel pack) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          packProvider(packId: basics.id).overrideWith(() => _FakePack(basics)),
          packProvider(packId: sleep.id).overrideWith(() => _FakePack(sleep)),
        ],
        child: MaterialApp(
          scaffoldMessengerKey: scaffoldMessengerKey,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: PackPathButton(pack: pack)),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('another pack offers "Show on Home"; tapping makes it the path', (
    tester,
  ) async {
    await pump(tester, sleep);

    expect(find.text(l10n.showOnHome), findsOneWidget);

    await tester.tap(find.text(l10n.showOnHome));
    await tester.pumpAndSettle();

    expect(prefs.getString(SharedPreferenceConstants.upNextPackId), 'sleep');
    // Flips to the status row naming the session that plays next.
    expect(find.text(l10n.yourPathStatusTitle(3, 7)), findsOneWidget);
    expect(find.text(l10n.yourPathNextSession('Session 3')), findsOneWidget);
  });

  testWidgets('replacing the default pack names it; Undo restores it', (
    tester,
  ) async {
    await pump(tester, sleep);

    await tester.tap(find.text(l10n.showOnHome));
    await tester.pumpAndSettle();

    expect(
      find.text(l10n.showOnHomeReplaced('Sleep', 'Basics')),
      findsOneWidget,
    );

    await tester.tap(find.text(l10n.undo));
    await tester.pumpAndSettle();

    // Home was on the default without an explicit choice; Undo restores that.
    expect(prefs.getString(SharedPreferenceConstants.upNextPackId), isNull);
    expect(find.text(l10n.showOnHome), findsOneWidget);
  });

  testWidgets('Undo restores an explicitly chosen previous pack', (
    tester,
  ) async {
    final work = _pack('work', 'Work life');
    await prefs.setString(SharedPreferenceConstants.upNextPackId, 'work');
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          packProvider(packId: work.id).overrideWith(() => _FakePack(work)),
          packProvider(packId: sleep.id).overrideWith(() => _FakePack(sleep)),
        ],
        child: MaterialApp(
          scaffoldMessengerKey: scaffoldMessengerKey,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: PackPathButton(pack: sleep)),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text(l10n.showOnHome));
    await tester.pumpAndSettle();
    expect(
      find.text(l10n.showOnHomeReplaced('Sleep', 'Work life')),
      findsOneWidget,
    );

    await tester.tap(find.text(l10n.undo));
    await tester.pumpAndSettle();
    expect(prefs.getString(SharedPreferenceConstants.upNextPackId), 'work');
  });

  testWidgets('a finished pack shows "All sessions done" once set', (
    tester,
  ) async {
    final done = _pack('done', 'Done', tracks: 2, done: 2);
    await pump(tester, done);

    await tester.tap(find.text(l10n.showOnHome));
    await tester.pumpAndSettle();

    expect(prefs.getString(SharedPreferenceConstants.upNextPackId), 'done');
    expect(find.text(l10n.yourPathAllDone), findsOneWidget);
  });

  testWidgets('current pack: the menu opens a sheet whose remove action falls '
      'back to the default pack', (tester) async {
    await prefs.setString(SharedPreferenceConstants.upNextPackId, 'sleep');
    await pump(tester, sleep);

    expect(find.byIcon(Icons.check_rounded), findsNothing);
    await tester.tap(find.byTooltip(l10n.yourPathOptions));
    await tester.pumpAndSettle();
    expect(find.text(l10n.yourPathSheetTitle), findsOneWidget);

    await tester.tap(find.text(l10n.removeFromYourPath));
    await tester.pumpAndSettle();

    expect(prefs.getString(SharedPreferenceConstants.upNextPackId), isNull);
    expect(find.text(l10n.showOnHome), findsOneWidget);
  });

  testWidgets('default pack as current path cannot be removed', (tester) async {
    await pump(tester, basics);

    await tester.tap(find.byTooltip(l10n.yourPathOptions));
    await tester.pumpAndSettle();

    expect(find.text(l10n.yourPathDefaultNote), findsOneWidget);
    expect(find.text(l10n.removeFromYourPath), findsNothing);
  });

  testWidgets('hidden for packs that contain sub-packs', (tester) async {
    final nested = PackModel(
      id: 'nested',
      title: 'Nested',
      items: const [
        PackItemsModel(
          type: TypeConstants.pack,
          id: 'child',
          title: 'Child',
          path: '/packs/child',
        ),
      ],
    );
    await pump(tester, nested);

    expect(find.text(l10n.showOnHome), findsNothing);
    expect(find.text(l10n.upNextTitle), findsNothing);
  });

  test('upNextPackIdProvider falls back to the basics pack', () {
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);
    expect(container.read(upNextPackIdProvider), ConfigConstants.basicsPackId);
  });
}
