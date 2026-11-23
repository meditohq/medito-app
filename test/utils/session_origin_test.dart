import 'package:flutter_test/flutter_test.dart';
import 'package:medito/utils/session_origin.dart';

void main() {
  final origin = SessionOrigin.instance;

  setUp(origin.resetForTesting);

  test('nothing noted reads as other with no pack', () {
    expect(origin.originFor('t1'), (source: SessionOrigin.other, packId: null));
  });

  test('returns the source and pack noted for that track', () {
    origin.note('t1', SessionOrigin.packTrackRow, packId: 'p1');

    expect(origin.originFor('t1'), (
      source: SessionOrigin.packTrackRow,
      packId: 'p1',
    ));
  });

  test('a note for another track is not credited to this one', () {
    origin.note('t1', SessionOrigin.packButton, packId: 'p1');

    expect(origin.originFor('t2'), (source: SessionOrigin.other, packId: null));
  });

  test('the latest note wins and drops the earlier pack', () {
    origin.note('t1', SessionOrigin.packButton, packId: 'p1');
    origin.note('t1', SessionOrigin.search);

    expect(origin.originFor('t1'), (
      source: SessionOrigin.search,
      packId: null,
    ));
  });

  test('reading does not clear it, so a replay keeps its origin', () {
    origin.note('t1', SessionOrigin.homeUpNext, packId: 'p1');
    origin.originFor('t1');

    expect(origin.originFor('t1'), (
      source: SessionOrigin.homeUpNext,
      packId: 'p1',
    ));
  });
}
