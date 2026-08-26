library;

import 'package:medito/constants/config_constants.dart';

/// The curated progression of packs behind "Your Path".
///
/// Order comes from the Medito team (2026-08-26). Positions 1-3 are the
/// beginner on-ramp; onboarding pins `regular_practice` users at position 4.
class PackSequence {
  const PackSequence._();

  static const List<String> ordered = <String>[
    'ELaBsJpiCol1RxdH', // 1  Getting started
    'HU1qzJUX2B4bAtrO', // 2  Learning to sit
    '5fms1CqfGpNDOQeV', // 3  Mindfulness
    'J3DsFVgKjZdbDiif', // 4  Deepen your practice
    'arRkkXD3Eh3N2Stf', // 5  Open awareness
    'BurMBDEI1HfmZmJz', // 6  Gratitude
    'QI0140HekrZ6SoLN', // 7  Compassion
    'Izv6OObcu3X2H9fu', // 8  30-Day mindfulness challenge
    'bmiHrmpuOGAGrtu2', // 9  Great thinkers
    'O2u0wyHNBcHA6u36', // 10 Personal insights
    'MN4dbqPbkKSPGGdo', // 11 Meditative insights
  ];

  static const String experiencedEntryPackId = 'J3DsFVgKjZdbDiif';

  static String get beginnerEntryPackId => ordered.first;

  /// Every pack above concatenated into one. Retired by attrition: it stays the
  /// no-pin fallback so pre-change users keep their place in it.
  static String get legacyMegapackId => ConfigConstants.basicsPackId;

  /// Analytics dimension: 'megapack' | 'sequence' | 'custom'.
  static String modeFor(String packId) {
    if (packId == legacyMegapackId) return 'megapack';
    if (contains(packId)) return 'sequence';
    return 'custom';
  }

  /// True when finishing [packId] means there is no course content left — the
  /// last pack on the path, or the megapack, which holds the same material.
  static bool isPathTerminal(String packId) =>
      isLast(packId) || packId == legacyMegapackId;

  /// Null when [packId] is last on the path or not on it at all.
  static String? nextPackAfter(String packId) {
    final index = ordered.indexOf(packId);
    if (index == -1 || index == ordered.length - 1) return null;
    return ordered[index + 1];
  }

  static bool isLast(String packId) =>
      ordered.isNotEmpty && ordered.last == packId;

  static bool contains(String packId) => ordered.contains(packId);

  /// 1-based position, or null when not on the path.
  static int? positionOf(String packId) {
    final index = ordered.indexOf(packId);
    return index == -1 ? null : index + 1;
  }
}
