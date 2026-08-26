import 'package:flutter_test/flutter_test.dart';
import 'package:medito/constants/config_constants.dart';
import 'package:medito/constants/pack_sequence.dart';
import 'package:medito/models/models.dart';
import 'package:medito/providers/home/up_next_provider.dart';

PackModel _pack({
  required String id,
  required int total,
  required int completed,
}) => PackModel(
  id: id,
  title: 'Pack $id',
  items: List.generate(
    total,
    (i) => PackItemsModel(
      type: 'track',
      id: '$id-item-$i',
      title: 'Item $i',
      path: '/t/$i',
      isCompleted: i < completed,
    ),
  ),
);

UpNextData _data(PackModel pack) {
  final completed = pack.items.where((i) => i.isCompleted == true).length;
  final isCompleted = pack.items.isNotEmpty && completed >= pack.items.length;
  return UpNextData(
    pack: pack,
    nextSession: (isCompleted || pack.items.isEmpty)
        ? null
        : pack.items.firstWhere(
            (i) => i.isCompleted != true,
            orElse: () => pack.items.first,
          ),
    completedCount: completed,
    totalCount: pack.items.length,
    nextPackId: isCompleted ? PackSequence.nextPackAfter(pack.id) : null,
    isEndOfPath: isCompleted && PackSequence.isPathTerminal(pack.id),
  );
}

void main() {
  group('PackSequence', () {
    test('walks the curated path in order', () {
      for (var i = 0; i < PackSequence.ordered.length - 1; i++) {
        expect(
          PackSequence.nextPackAfter(PackSequence.ordered[i]),
          PackSequence.ordered[i + 1],
          reason: 'position ${i + 1} should hand off to ${i + 2}',
        );
      }
    });

    test('the last pack has no successor', () {
      expect(PackSequence.nextPackAfter(PackSequence.ordered.last), isNull);
      expect(PackSequence.isLast(PackSequence.ordered.last), isTrue);
    });

    test('off-path packs have no successor and are not last', () {
      for (final id in [PackSequence.legacyMegapackId, 'not-a-real-pack']) {
        expect(PackSequence.nextPackAfter(id), isNull);
        expect(PackSequence.isLast(id), isFalse);
        expect(PackSequence.contains(id), isFalse);
        expect(PackSequence.positionOf(id), isNull);
      }
    });

    test('the onboarding entry points sit on the path', () {
      expect(PackSequence.positionOf(PackSequence.experiencedEntryPackId), 4);
      expect(PackSequence.positionOf(PackSequence.beginnerEntryPackId), 1);
      expect(
        PackSequence.nextPackAfter(PackSequence.experiencedEntryPackId),
        isNotNull,
        reason: 'an experienced user must still have somewhere to progress to',
      );
    });

    test('the legacy megapack is terminal but not on the path', () {
      expect(PackSequence.legacyMegapackId, ConfigConstants.basicsPackId);
      expect(PackSequence.isPathTerminal(PackSequence.legacyMegapackId), isTrue);
      expect(PackSequence.contains(PackSequence.legacyMegapackId), isFalse);
      expect(
        PackSequence.ordered.contains(PackSequence.legacyMegapackId),
        isFalse,
      );
    });

    test('the last pack on the path is terminal', () {
      expect(PackSequence.isPathTerminal(PackSequence.ordered.last), isTrue);
      expect(PackSequence.isPathTerminal(PackSequence.ordered.first), isFalse);
    });

    test('the full path is 11 packs', () {
      expect(PackSequence.ordered.length, 11);
    });

    test('positions are 1-based', () {
      expect(PackSequence.positionOf(PackSequence.ordered.first), 1);
      expect(
        PackSequence.positionOf(PackSequence.ordered.last),
        PackSequence.ordered.length,
      );
    });

    test('modeFor separates the three Up Next cohorts', () {
      expect(PackSequence.modeFor(PackSequence.legacyMegapackId), 'megapack');
      for (final id in PackSequence.ordered) {
        expect(PackSequence.modeFor(id), 'sequence', reason: 'pack $id');
      }
      expect(PackSequence.modeFor('hand-pinned-from-explore'), 'custom');
    });

    test('ids are unique — a duplicate would make the path loop', () {
      expect(
        PackSequence.ordered.toSet().length,
        PackSequence.ordered.length,
      );
    });
  });

  group('UpNextData completion', () {
    test('an empty pack is not treated as completed', () {
      final data = _data(_pack(id: 'empty', total: 0, completed: 0));
      expect(data.isCompleted, isFalse);
      expect(data.nextPackId, isNull);
    });

    test('a partially complete pack surfaces the next session', () {
      final data = _data(
        _pack(id: PackSequence.ordered.first, total: 5, completed: 2),
      );
      expect(data.isCompleted, isFalse);
      expect(data.nextSession?.id, '${PackSequence.ordered.first}-item-2');
      expect(data.nextPackId, isNull, reason: 'no successor until completed');
    });

    test('completing a mid-path pack offers the next one', () {
      final data = _data(
        _pack(id: PackSequence.ordered.first, total: 3, completed: 3),
      );
      expect(data.isCompleted, isTrue);
      expect(data.nextSession, isNull);
      expect(data.nextPackId, PackSequence.ordered[1]);
      expect(data.isEndOfPath, isFalse);
    });

    test('completing the final pack is the end of the path', () {
      final data = _data(
        _pack(id: PackSequence.ordered.last, total: 3, completed: 3),
      );
      expect(data.isCompleted, isTrue);
      expect(data.nextPackId, isNull);
      expect(data.isEndOfPath, isTrue);
    });

    test('completing the legacy megapack counts as the end of the path', () {
      final data = _data(
        _pack(id: PackSequence.legacyMegapackId, total: 2, completed: 2),
      );
      expect(data.isCompleted, isTrue);
      expect(data.nextPackId, isNull, reason: 'never offer a successor to it');
      expect(data.isEndOfPath, isTrue);
    });

    test('completing an unknown pack is a plain completion', () {
      final data = _data(_pack(id: 'hand-pinned', total: 2, completed: 2));
      expect(data.isCompleted, isTrue);
      expect(data.nextPackId, isNull);
      expect(data.isEndOfPath, isFalse);
    });
  });
}
