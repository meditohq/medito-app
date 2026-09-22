import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medito/constants/pack_sequence.dart';
import 'package:medito/models/models.dart';
import 'package:medito/providers/home/up_next_provider.dart';
import 'package:medito/providers/pack/pack_provider.dart';

class _FakePack extends Pack {
  _FakePack(this.initial);
  final AsyncValue<PackModel> initial;

  @override
  AsyncValue<PackModel> build({required String packId}) => initial;

  void update(AsyncValue<PackModel> value) => state = value;
}

PackModel _pack(String id, {int completed = 2, int total = 2}) => PackModel(
  id: id,
  title: 'Pack $id',
  items: List.generate(
    total,
    (i) => PackItemsModel(
      type: 'track',
      id: '$id-$i',
      title: 'Session $i',
      path: '/tracks/$id-$i',
      isCompleted: i < completed,
    ),
  ),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final ids = PackSequence.ordered;

  ProviderContainer container({
    String? pinned,
    Map<String, AsyncValue<PackModel>> packs = const {},
  }) {
    final current = pinned ?? ids.first;
    final result = ProviderContainer(
      overrides: [
        upNextPackIdProvider.overrideWithValue(current),
        for (final id in {...ids, current})
          packProvider(
            packId: id,
          ).overrideWith(() => _FakePack(packs[id] ?? AsyncData(_pack(id)))),
      ],
    );
    addTearDown(result.dispose);
    return result;
  }

  test('skips consecutive completed packs before offering a successor', () {
    final c = container(
      packs: {ids[4]: AsyncData(_pack(ids[4], completed: 1))},
    );
    final data = c.read(upNextProvider).requireValue;
    expect(data.pack.id, ids.first);
    expect(data.isCompleted, isTrue);
    expect(data.nextPackId, ids[4]);
    expect(data.isEndOfPath, isFalse);

    // Selecting the offered pack leads straight to an unfinished session.
    final next = container(
      pinned: data.nextPackId,
      packs: {ids[4]: AsyncData(_pack(ids[4], completed: 1))},
    ).read(upNextProvider).requireValue;
    expect(next.nextSession?.id, '${ids[4]}-1');
    expect(next.isCompleted, isFalse);
  });

  test('offers the immediate successor when it has unfinished sessions', () {
    final c = container(
      packs: {ids[1]: AsyncData(_pack(ids[1], completed: 0))},
    );
    expect(c.read(upNextProvider).requireValue.nextPackId, ids[1]);
  });

  test('all remaining packs completed means the path is complete', () {
    final data = container().read(upNextProvider).requireValue;
    expect(data.nextPackId, isNull);
    expect(data.isEndOfPath, isTrue);
  });

  test('does not inspect successors while the pinned pack is unfinished', () {
    final c = container(
      packs: {
        ids.first: AsyncData(_pack(ids.first, completed: 1)),
        ids[1]: const AsyncLoading(),
      },
    );
    final data = c.read(upNextProvider).requireValue;
    expect(data.nextSession?.id, '${ids.first}-1');
    expect(data.nextPackId, isNull);
    expect(data.isEndOfPath, isFalse);
  });

  test('waits for candidate completion data before offering a pack', () {
    final c = container(packs: {ids[1]: const AsyncLoading()});
    expect(c.read(upNextProvider).isLoading, isTrue);
    (c.read(packProvider(packId: ids[1]).notifier) as _FakePack).update(
      AsyncData(_pack(ids[1], completed: 1)),
    );
    expect(c.read(upNextProvider).requireValue.nextPackId, ids[1]);
  });

  test('a failed candidate fetch does not imply path completion', () {
    final error = StateError('offline');
    final c = container(packs: {ids[1]: AsyncError(error, StackTrace.current)});
    expect(c.read(upNextProvider).error, same(error));
  });

  test('updates the successor when a later pack is marked incomplete', () {
    final c = container();
    expect(c.read(upNextProvider).requireValue.isEndOfPath, isTrue);
    (c.read(packProvider(packId: ids[2]).notifier) as _FakePack).update(
      AsyncData(_pack(ids[2], completed: 0)),
    );
    expect(c.read(upNextProvider).requireValue.nextPackId, ids[2]);
  });

  test('skips empty packs which have no session to start', () {
    final c = container(
      packs: {
        ids[1]: AsyncData(_pack(ids[1], total: 0)),
        ids[2]: AsyncData(_pack(ids[2], completed: 0)),
      },
    );
    expect(c.read(upNextProvider).requireValue.nextPackId, ids[2]);
  });

  test('legacy and custom packs keep their existing completion behavior', () {
    for (final id in [PackSequence.legacyMegapackId, 'custom']) {
      final data = container(pinned: id).read(upNextProvider).requireValue;
      expect(data.nextPackId, isNull);
      expect(data.isEndOfPath, id == PackSequence.legacyMegapackId);
    }
  });
}
