/// Each bell is independently selectable. Pattern names are persisted and sent
/// to Android; retain the names of the original beginning/end presets.
enum SessionBellCue { beginning, middle, end }

enum SessionBellPattern {
  none(false, false, false),
  beginning(true, false, false),
  middle(false, true, false),
  end(false, false, true),
  beginningMiddle(true, true, false),
  beginningEnd(true, false, true),
  middleEnd(false, true, true),
  beginningMiddleEnd(true, true, true);

  const SessionBellPattern(this.hasBeginning, this.hasMiddle, this.hasEnd);

  final bool hasBeginning;
  final bool hasMiddle;
  final bool hasEnd;

  bool includes(SessionBellCue cue) => switch (cue) {
    SessionBellCue.beginning => hasBeginning,
    SessionBellCue.middle => hasMiddle,
    SessionBellCue.end => hasEnd,
  };

  SessionBellPattern withCue(SessionBellCue cue, bool selected) {
    final beginning = cue == SessionBellCue.beginning ? selected : hasBeginning;
    final middle = cue == SessionBellCue.middle ? selected : hasMiddle;
    final end = cue == SessionBellCue.end ? selected : hasEnd;
    return values.firstWhere(
      (pattern) =>
          pattern.hasBeginning == beginning &&
          pattern.hasMiddle == middle &&
          pattern.hasEnd == end,
    );
  }
}
