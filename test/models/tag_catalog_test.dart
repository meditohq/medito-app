import 'package:flutter_test/flutter_test.dart';
import 'package:medito/models/tags/tag_model.dart';

void main() {
  final json = {
    'tags': [
      {'id': 'sleep', 'group': 'goal', 'description': 'd'},
      {'id': 'calm', 'group': 'goal', 'description': 'd'},
      {'id': 'talk', 'group': 'format', 'description': 'd'},
      {'group': 'goal'}, // no id → dropped
      'garbage',
    ],
    'trackTags': {
      'a': ['sleep', 'calm'],
      'b': ['sleep'],
      'c': ['talk', 42, 'unknown_tag'],
      7: ['sleep'], // non-string key → dropped
    },
  };

  test('parses leniently and drops malformed entries', () {
    final c = TagCatalog.fromJson(json);
    expect(c.tags.map((t) => t.id), ['sleep', 'calm', 'talk']);
    expect(c.trackTags.keys, ['a', 'b', 'c']);
    expect(c.trackTags['c'], ['talk', 'unknown_tag']);
    expect(c.isEmpty, isFalse);
  });

  test(
    'keeps a tag whose group/description are non-string, defaulting them',
    () {
      final c = TagCatalog.fromJson({
        'tags': [
          {'id': 'sleep', 'group': 7, 'description': false},
        ],
        'trackTags': {
          'a': ['sleep'],
        },
      });
      expect(c.tags.map((t) => t.id), ['sleep']);
      expect(c.tag('sleep')!.group, '');
      expect(c.tag('sleep')!.description, '');
    },
  );

  test('tagsForTracks counts tracks missing from the catalog', () {
    final c = TagCatalog.fromJson(json);
    // one tagged track (a: sleep,calm) + one missing track → denominator 2,
    // threshold 1, so a tag on the single known track no longer sweeps in.
    expect(c.tagsForTracks(['a', 'missing']).map((t) => t.id), [
      'sleep',
      'calm',
    ]);
    // one tagged track + two missing → denominator 3, threshold 2, nothing
    // reaches half.
    expect(c.tagsForTracks(['a', 'missing1', 'missing2']), isEmpty);
  });

  test('malformed top level yields the empty catalog', () {
    expect(TagCatalog.fromJson({}).isEmpty, isTrue);
    expect(TagCatalog.fromJson({'tags': 'x', 'trackTags': []}).isEmpty, isTrue);
    expect(TagCatalog.fromJson({'error': 'nope'}).isEmpty, isTrue);
  });

  test('tagsForTrack keeps order and skips unknown tag ids', () {
    final c = TagCatalog.fromJson(json);
    expect(c.tagsForTrack('a').map((t) => t.id), ['sleep', 'calm']);
    expect(c.tagsForTrack('c').map((t) => t.id), ['talk']);
    expect(c.tagsForTrack('missing'), isEmpty);
  });

  test('tagsForTracks needs at least half the tracks, most common first', () {
    final c = TagCatalog.fromJson(json);
    // a, b, c: sleep on 2/3, calm on 1/3, talk on 1/3 → threshold 2
    expect(c.tagsForTracks(['a', 'b', 'c']).map((t) => t.id), ['sleep']);
    // a, b: sleep 2/2, calm 1/2 → threshold 1
    expect(c.tagsForTracks(['a', 'b']).map((t) => t.id), ['sleep', 'calm']);
    expect(c.tagsForTracks(['missing']), isEmpty);
    expect(c.tagsForTracks([]), isEmpty);
  });

  test('trackCounts counts tracks per tag', () {
    final c = TagCatalog.fromJson(json);
    expect(c.trackCounts, {'sleep': 2, 'calm': 1, 'talk': 1, 'unknown_tag': 1});
  });
}
