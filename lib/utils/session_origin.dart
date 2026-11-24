/// Where a session was started from, for `audio_session_started`
/// (`start_source` + `pack_id`).
///
/// Entry points call [note] just before they open a track or the player;
/// `PlayerProvider.play()` reads it back with [originFor]. It is keyed by
/// track id so a stale note (the user opened a track, backed out, and later
/// played something else from a screen that doesn't note) reads as [other]
/// instead of being credited to the wrong screen.
///
/// Deliberately global (not a provider), like `LaunchSourceTracker`:
/// deep-link and notification handlers route before a widget tree exists.
class SessionOrigin {
  SessionOrigin._();
  static final SessionOrigin instance = SessionOrigin._();

  /// The Home hero ("Start here" / "Continue").
  static const homeUpNext = 'home_up_next';
  static const homeShortcut = 'home_shortcut';
  static const homeCarousel = 'home_carousel';

  /// The pack screen's Start/Continue play button (also puts it on Home).
  static const packButton = 'pack_button';

  /// A single track row tapped in a pack's list (never changes Home).
  static const packTrackRow = 'pack_track_row';
  static const search = 'search';
  static const tag = 'tag';
  static const favorites = 'favorites';
  static const downloads = 'downloads';
  static const history = 'history';
  static const deeplink = 'deeplink';
  static const notification = 'notification';
  static const timer = 'timer';

  /// No entry point noted this track.
  static const other = 'other';

  String? _trackId;
  String _source = other;
  String? _packId;

  /// Records that [trackId] is about to be opened from [source]. [packId] is
  /// the pack the user reached it through, when there is one.
  void note(String trackId, String source, {String? packId}) {
    _trackId = trackId;
    _source = source;
    _packId = packId;
  }

  /// The noted origin for [trackId], or [other] with no pack when the latest
  /// note was for a different track. Not cleared on read: replaying the same
  /// track keeps its origin.
  ({String source, String? packId}) originFor(String trackId) =>
      _trackId == trackId
      ? (source: _source, packId: _packId)
      : (source: other, packId: null);

  void resetForTesting() {
    _trackId = null;
    _source = other;
    _packId = null;
  }
}
