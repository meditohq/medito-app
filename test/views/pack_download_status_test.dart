import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medito/constants/types/type_constants.dart';
import 'package:medito/constants/theme/app_theme.dart';
import 'package:medito/l10n/app_localizations.dart';
import 'package:medito/models/favorites/favorite_item.dart';
import 'package:medito/models/pack/pack_model.dart';
import 'package:medito/models/track/track.dart';
import 'package:medito/providers/favorites/favorites_provider.dart';
import 'package:medito/providers/providers.dart';
import 'package:medito/views/pack/widgets/pack_item_widget.dart';
import 'package:medito/views/player/widgets/bottom_actions/pack_view_bottom_bar.dart';

const _first = PackItemsModel(
  type: TypeConstants.track,
  id: 'one',
  title: 'First track',
  path: '/one',
);
const _second = PackItemsModel(
  type: TypeConstants.track,
  id: 'two',
  title: 'Second track',
  path: '/two',
);
const _pack = PackModel(
  id: 'test',
  title: 'Test pack',
  items: [_first, _second],
);
Track _track(String id) => Track(
  id: id,
  title: id,
  description: '',
  coverUrl: '',
  isPublished: true,
  hasBackgroundSound: false,
  voices: [],
);

class _Pack extends Pack {
  _Pack(this.pack);
  final PackModel pack;
  @override
  AsyncValue<PackModel> build({required String packId}) => AsyncData(pack);
}

class _Favorites extends FavoritesNotifier {
  @override
  Future<List<FavoriteItem>> build() async => [];
}

Future<void> _showMenu(
  WidgetTester tester,
  PackModel pack,
  List<Track> downloads,
) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        packProvider(packId: pack.id).overrideWith(() => _Pack(pack)),
        favoritesNotifierProvider.overrideWith(_Favorites.new),
        downloadedTracksProvider.overrideWith((ref) async => downloads),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) =>
            Theme(data: appTheme(context), child: child!),
        home: Scaffold(
          bottomNavigationBar: PackViewBottomBar(
            packId: pack.id,
            packName: pack.title,
            onBackPressed: () {},
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  if (find.byIcon(Icons.more_vert).evaluate().isNotEmpty) {
    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
  }
}

void main() {
  testWidgets('folder-only pack keeps sharing but hides downloads', (
    tester,
  ) async {
    await _showMenu(
      tester,
      _pack.copyWith(items: [_first.copyWith(type: TypeConstants.pack)]),
      [],
    );
    expect(find.text('Download all'), findsNothing);
    expect(find.text('Download remaining tracks'), findsNothing);
    expect(find.text('Share'), findsNothing);
    expect(find.byTooltip('Share'), findsOneWidget);
    expect(find.byIcon(Icons.more_vert), findsNothing);
  });

  testWidgets('mixed pack hides bulk download', (tester) async {
    await _showMenu(
      tester,
      _pack.copyWith(
        items: [
          _first,
          _second.copyWith(type: TypeConstants.pack),
        ],
      ),
      [],
    );
    expect(find.text('Download all'), findsNothing);
    expect(find.byIcon(Icons.more_vert), findsNothing);
  });

  testWidgets('track pack offers download all when nothing is saved', (
    tester,
  ) async {
    await _showMenu(tester, _pack, []);
    expect(find.text('Download all'), findsOneWidget);
    expect(find.text('Download remaining tracks'), findsNothing);
    expect(find.text('Share'), findsNothing);
    expect(tester.widget<Text>(find.text('Download all')).style?.fontSize, 16);
  });

  testWidgets(
    'partly saved pack shows count and remaining action without track list',
    (tester) async {
      await _showMenu(tester, _pack, [_track('one')]);
      expect(find.text('Download remaining tracks'), findsOneWidget);
      expect(find.text('1 of 2 tracks downloaded'), findsOneWidget);
      expect(
        tester
            .widget<Text>(find.text('Download remaining tracks'))
            .style
            ?.fontSize,
        16,
      );
      expect(
        tester
            .widget<Text>(find.text('1 of 2 tracks downloaded'))
            .style
            ?.fontSize,
        14,
      );
      expect(find.text('First track'), findsNothing);
      expect(find.text('Second track'), findsNothing);
    },
  );

  testWidgets('fully saved pack shows completion and delete action', (
    tester,
  ) async {
    await _showMenu(tester, _pack, [_track('one'), _track('two')]);
    expect(find.text('All sessions downloaded'), findsOneWidget);
    expect(find.text('Delete downloads'), findsOneWidget);
    expect(find.text('Download remaining tracks'), findsNothing);
  });

  testWidgets('only downloaded track rows show an offline marker', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          downloadedTracksProvider.overrideWith((ref) async => [_track('one')]),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(
            body: Column(
              children: [
                PackItemWidget(item: _first),
                PackItemWidget(item: _second),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.widgetWithText(PackItemWidget, 'First track'),
        matching: find.byTooltip('Downloaded'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.widgetWithText(PackItemWidget, 'Second track'),
        matching: find.byTooltip('Downloaded'),
      ),
      findsNothing,
    );
  });
}
