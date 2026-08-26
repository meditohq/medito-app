/// The curated progression of packs that makes up "Your Path".
///
/// When a user finishes a pack in this list, the Up Next card shows a completed
/// state whose CTA pins the next pack in the sequence. Before this existed,
/// finishing a pinned pack silently cleared the pin and fell back to the
/// beginner Basics pack — or, if Basics was already done, hid the Up Next card
/// entirely with no acknowledgement and no way forward.
///
/// Order is meaningful and comes from the Medito team (2026-08-26). Keep it as a
/// plain const list: it is read on the home screen's hot path, needs no API or
/// CMS change, and ships in a Shorebird patch.
///
/// Packs NOT in this list still get a completed state, but with no successor to
/// offer — see [nextPackAfter]. The important one is [legacyMegapackId], which
/// holds all of this same content in a single pack and is treated as the end of
/// the path when finished.
library;

import 'package:medito/constants/config_constants.dart';

class PackSequence {
  const PackSequence._();

  /// Ordered pack ids. Titles are for readability only — the app never reads
  /// them, it resolves the real title from the pack API.
  ///
  /// Positions 1-3 are the beginner on-ramp. Position 4 is where onboarding
  /// pins users who answer `regular_practice`, so an experienced user starts
  /// mid-path and progresses 4 -> 11 from there.
  static const List<String> ordered = <String>[
    'ELaBsJpiCol1RxdH', // 1  Getting started
    'HU1qzJUX2B4bAtrO', // 2  Learning to sit
    '5fms1CqfGpNDOQeV', // 3  Mindfulness
    'J3DsFVgKjZdbDiif', // 4  Deepen your practice  <- onboarding "experienced" pin
    'arRkkXD3Eh3N2Stf', // 5  Open awareness
    'BurMBDEI1HfmZmJz', // 6  Gratitude
    'QI0140HekrZ6SoLN', // 7  Compassion
    'Izv6OObcu3X2H9fu', // 8  30-Day mindfulness challenge
    'bmiHrmpuOGAGrtu2', // 9  Great thinkers
    'O2u0wyHNBcHA6u36', // 10 Personal insights
    'MN4dbqPbkKSPGGdo', // 11 Meditative insights
  ];

  /// Where onboarding pins a user who answers `regular_practice` — position 4,
  /// skipping the three beginner packs. Kept here rather than inline in the
  /// onboarding screen so it cannot drift out of the sequence unnoticed; a test
  /// asserts its position.
  static const String experiencedEntryPackId = 'J3DsFVgKjZdbDiif';

  /// Where onboarding pins everyone else — the top of the path.
  static String get beginnerEntryPackId => ordered.first;

  /// The legacy "megapack": every course pack in this sequence concatenated
  /// into one, and still [ConfigConstants.basicsPackId]. It existed so Up Next
  /// could cycle through all the course content without the app holding a list
  /// — which is exactly what made it impossible to drop an experienced user in
  /// partway. It is being retired by attrition rather than deleted: onboarding
  /// now pins every new user onto the real sequence, and this pack stays as the
  /// no-pin fallback so anyone who onboarded earlier keeps their place in it.
  /// See [isPathTerminal].
  static String get legacyMegapackId => ConfigConstants.basicsPackId;

  /// How the user's Up Next is configured, as an analytics dimension.
  ///
  /// This is the cut that answers whether splitting the megapack into a stepped
  /// path actually changes behaviour: [megapack] users are the pre-change
  /// cohort still riding the no-pin fallback, [sequence] users were pinned onto
  /// the curated path at onboarding, and [custom] users hand-pinned something
  /// from Explore. Reported on every Up Next event so engagement can be
  /// compared across the three without a join.
  static String modeFor(String packId) {
    if (packId == legacyMegapackId) return 'megapack';
    if (contains(packId)) return 'sequence';
    return 'custom';
  }

  /// Whether finishing [packId] means the user has finished all of the course
  /// content — either the last pack on the path, or the whole megapack, which
  /// contains the same material. Both are the end-of-path moment.
  static bool isPathTerminal(String packId) =>
      isLast(packId) || packId == legacyMegapackId;

  /// The pack that follows [packId] in the sequence, or null when [packId] is
  /// the last entry or is not part of the sequence at all.
  ///
  /// A null return is the "end of the path" case: the completed state renders
  /// without a next-pack CTA. What that state should ultimately offer is still
  /// an open product decision — [PackSequence.isLast] exists so the analytics
  /// can tell us how many users actually reach it before we design for it.
  static String? nextPackAfter(String packId) {
    final index = ordered.indexOf(packId);
    if (index == -1 || index == ordered.length - 1) return null;
    return ordered[index + 1];
  }

  /// Whether [packId] is the final pack in the sequence, as distinct from not
  /// being in the sequence at all. Both yield a null successor, but only this
  /// one means the user has finished the whole path.
  static bool isLast(String packId) =>
      ordered.isNotEmpty && ordered.last == packId;

  /// Whether [packId] is part of the curated path.
  static bool contains(String packId) => ordered.contains(packId);

  /// 1-based position in the path, or null when [packId] is not in it. Used as
  /// an analytics dimension so drop-off along the path is measurable.
  static int? positionOf(String packId) {
    final index = ordered.indexOf(packId);
    return index == -1 ? null : index + 1;
  }
}
