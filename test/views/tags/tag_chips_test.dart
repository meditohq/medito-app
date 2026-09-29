import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medito/l10n/app_localizations.dart';
import 'package:medito/models/explore/explore_list_item.dart';
import 'package:medito/models/tags/tag_model.dart';
import 'package:medito/providers/tags/tags_provider.dart';
import 'package:medito/repositories/tags/tags_repository.dart';
import 'package:medito/views/tags/widgets/tag_chip.dart';
import 'package:medito/views/tags/widgets/tag_chips.dart';

class _FakeTagsRepository implements TagsRepository {
  _FakeTagsRepository({this.catalog, this.error});
  final TagCatalog? catalog;
  final Object? error;

  @override
  Future<TagCatalog> fetchCatalog() async {
    if (error != null) throw error!;
    return catalog!;
  }

  @override
  Future<List<TrackItem>> fetchTracksForTag(String tagId) async => const [];
}

Widget _app(TagsRepository repo, Widget child) {
  return ProviderScope(
    overrides: [tagsRepositoryProvider.overrideWithValue(repo)],
    retry: (_, _) => null,
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: child),
    ),
  );
}

void main() {
  final catalog = TagCatalog.fromJson({
    'tags': [
      {'id': 'sleep', 'group': 'goal', 'description': 'd'},
      {'id': 'stress', 'group': 'goal', 'description': 'd'},
      {'id': 'guided_meditation', 'group': 'format', 'description': 'd'},
      {'id': 'unused', 'group': 'goal', 'description': 'd'},
    ],
    'trackTags': {
      't1': ['sleep', 'guided_meditation'],
      't2': ['sleep', 'stress', 'guided_meditation'],
    },
  });

  testWidgets('explore chips render nothing when the API fails', (tester) async {
    await tester.pumpWidget(
      _app(_FakeTagsRepository(error: Exception('500')), const ExploreTagChips()),
    );
    await tester.pumpAndSettle();
    expect(find.byType(TagChip), findsNothing);
    expect(tester.getSize(find.byType(ExploreTagChips)), Size.zero);
  });

  testWidgets('explore chips list used, non-hidden tags most-used first', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(_FakeTagsRepository(catalog: catalog), const ExploreTagChips()),
    );
    await tester.pumpAndSettle();
    final labels = tester
        .widgetList<TagChip>(find.byType(TagChip))
        .map((c) => c.label)
        .toList();
    expect(labels, ['Sleep', 'Stress']); // guided_meditation hidden, unused has no tracks
  });

  testWidgets('track chips show that track\'s tags and open the tag page', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(_FakeTagsRepository(catalog: catalog), const TrackTagChips(trackId: 't2')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Sleep'), findsOneWidget);
    expect(find.text('Stress'), findsOneWidget);
    expect(find.text('Guided meditation'), findsNothing);

    await tester.tap(find.text('Stress'));
    await tester.pumpAndSettle();
    // The tag page's app bar carries the tag label.
    expect(find.byType(AppBar), findsOneWidget);
    expect(find.text('Stress'), findsOneWidget);
  });

  testWidgets('track chips render nothing for an untagged track', (tester) async {
    await tester.pumpWidget(
      _app(_FakeTagsRepository(catalog: catalog), const TrackTagChips(trackId: 'nope')),
    );
    await tester.pumpAndSettle();
    expect(find.byType(TagChip), findsNothing);
  });

  testWidgets('pack chips show tags shared by at least half the tracks', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        _FakeTagsRepository(catalog: catalog),
        const PackTagChips(trackIds: ['t1', 't2']),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Sleep'), findsOneWidget); // 2/2
    expect(find.text('Stress'), findsOneWidget); // 1/2 meets threshold
    expect(find.text('Guided meditation'), findsNothing); // hidden
  });
}
