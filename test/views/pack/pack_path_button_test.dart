import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medito/constants/config_constants.dart';
import 'package:medito/constants/pack_sequence.dart';
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
  late List<String> started;

  final basics = _pack(ConfigConstants.basicsPackId, 'Basics');
  final sleep = _pack('sleep', 'Sleep', tracks: 7, done: 3);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    l10n = await AppLocalizations.delegate.load(const Locale('en'));
    started = [];
  });

  Future<void> fakeStart(
    BuildContext context,
    WidgetRef ref, {
    required String trackId,
    required String path,
  }) async => started.add(trackId);

  Future<void> pump(
    WidgetTester tester,
    PackModel pack, {
    List<PackModel> others = const [],
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          for (final p in [basics, sleep, ...others])
            packProvider(packId: p.id).overrideWith(() => _FakePack(p)),
        ],
        child: MaterialApp(
          scaffoldMessengerKey: scaffoldMessengerKey,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: PackPathButton(
              pack: pack,
              onStartSession: fakeStart,
              child: const SizedBox(height: 40),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('an untouched pack says Start', (tester) async {
    await pump(tester, _pack('fresh', 'Fresh', done: 0));

    final handle = tester.ensureSemantics();
    expect(
      find.bySemanticsLabel(RegExp('^${l10n.packStart}: Session 0')),
      findsOneWidget,
    );
    handle.dispose();
  });

  testWidgets('Continue plays the next session and puts the pack on Home', (
    tester,
  ) async {
    await pump(tester, sleep);

    final handle = tester.ensureSemantics();
    expect(
      find.bySemanticsLabel(
        '${l10n.packContinue}: Session 3. ${l10n.upNextProgress(3, 7)}',
      ),
      findsOneWidget,
    );
    handle.dispose();

    await tester.tap(find.byIcon(Icons.play_arrow_rounded));
    await tester.pumpAndSettle();

    expect(started, ['sleep-3']);
    expect(prefs.getString(SharedPreferenceConstants.upNextPackId), 'sleep');
    expect(find.text(l10n.packAddedToHome), findsOneWidget);
  });

  testWidgets('Undo after replacing the default restores the default', (
    tester,
  ) async {
    await pump(tester, sleep);

    await tester.tap(find.byIcon(Icons.play_arrow_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.undo));
    await tester.pumpAndSettle();

    // Home was on the default without an explicit choice; Undo restores that.
    expect(prefs.getString(SharedPreferenceConstants.upNextPackId), isNull);
  });

  testWidgets('Undo restores an explicitly chosen previous pack', (
    tester,
  ) async {
    final work = _pack('work', 'Work life');
    await prefs.setString(SharedPreferenceConstants.upNextPackId, 'work');
    await pump(tester, sleep, others: [work]);

    await tester.tap(find.byIcon(Icons.play_arrow_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.undo));
    await tester.pumpAndSettle();

    expect(prefs.getString(SharedPreferenceConstants.upNextPackId), 'work');
  });

  testWidgets('remembers the series pack it replaced, for Remove on Home', (
    tester,
  ) async {
    final gettingStarted = _pack(PackSequence.beginnerEntryPackId, 'Start');
    final work = _pack('work', 'Work life');
    await prefs.setString(
      SharedPreferenceConstants.upNextPackId,
      gettingStarted.id,
    );
    await pump(tester, work, others: [gettingStarted, work]);
    await tester.tap(find.byIcon(Icons.play_arrow_rounded));
    await tester.pumpAndSettle();
    expect(
      prefs.getString(SharedPreferenceConstants.upNextReturnPackId),
      gettingStarted.id,
    );

    // Hopping to another hand-picked pack keeps the series position.
    await pump(tester, sleep, others: [gettingStarted, work]);
    await tester.tap(find.byIcon(Icons.play_arrow_rounded));
    await tester.pumpAndSettle();
    expect(prefs.getString(SharedPreferenceConstants.upNextPackId), 'sleep');
    expect(
      prefs.getString(SharedPreferenceConstants.upNextReturnPackId),
      gettingStarted.id,
    );
  });

  testWidgets('the pack already on Home just plays, with no snackbar', (
    tester,
  ) async {
    await prefs.setString(SharedPreferenceConstants.upNextPackId, 'sleep');
    await pump(tester, sleep);

    await tester.tap(find.byIcon(Icons.play_arrow_rounded));
    await tester.pumpAndSettle();

    expect(started, ['sleep-3']);
    expect(find.text(l10n.packAddedToHome), findsNothing);
  });

  testWidgets('a finished pack shows "All sessions done" and does nothing', (
    tester,
  ) async {
    await pump(tester, _pack('done', 'Done', tracks: 2, done: 2));

    await tester.tap(find.byIcon(Icons.check_rounded));
    await tester.pumpAndSettle();

    expect(started, isEmpty);
    expect(prefs.getString(SharedPreferenceConstants.upNextPackId), isNull);
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

    expect(find.byIcon(Icons.play_arrow_rounded), findsNothing);
  });

  test('upNextPackIdProvider falls back to the basics pack', () {
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);
    expect(container.read(upNextPackIdProvider), ConfigConstants.basicsPackId);
  });
}
