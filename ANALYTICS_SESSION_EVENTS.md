# Audio Session Analytics — `started` / `abandoned`

Spec for two new GA4 (Firebase Analytics) events that let us compute meditation
**completion rate** and **drop-off distribution**. Today only
`audio_session_completed` is logged, so we have a numerator with no denominator
and no idea where people quit.

GA4 export: BigQuery `medito-9165c.analytics_451310720`.

## Events

### 1. `audio_session_started`
Fires **once** when playback of a track actually begins.

| Param | Type | Source |
|-------|------|--------|
| `audioFileId` | string | `PlaybackRequest.fileId` |
| `audioFileGuide` | string | `PlaybackRequest.guideName` (falls back to `'unknown'`) |
| `audioFileDuration` | int (ms) | `PlaybackRequest.duration` (the file's total length in ms) |

Same three params as `audio_session_completed` so the two join cleanly.

### 2. `audio_session_abandoned`
Fires **once** when a started session ends **without** completing.

| Param | Type | Source |
|-------|------|--------|
| `audioFileId` | string | active session |
| `audioFileGuide` | string | active session |
| `audioFileDuration` | int (ms) | live measured duration, falls back to the session's start duration |
| `percent_completed` | int | `round(position / duration * 100)` rounded to nearest 10, clamped to **0…90** |
| `elapsed_seconds` | int | `round(position_ms / 1000)` |

`percent_completed` is intentionally bucketed (0,10,20,…,90) — we want drop-off
*distribution*, not raw precision, and bucketing keeps GA4 cardinality low. It is
clamped to a max of 90 because a session that reached ~100% is a completion, not
an abandonment.

## The session lifecycle

A single Dart owner, [`AudioSessionTracker`](lib/utils/audio_session_tracker.dart),
tracks one active session at a time and is the only place these two events are
fired. It mirrors the existing `audio_session_completed` path, which is also
ultimately fired from Dart (`handleStats` in `stats_updater.dart`) on both
platforms.

```
play() ───────────────► onStarted()      → fire audio_session_started
                                            (persist in-progress record)
position stream (~1s) ─► onPositionUpdate → keep last position; persist (throttled)
completion ───────────► onCompleted()     → clear record  (NO abandoned)
switch track ─────────► onStarted()       → abandon previous, then start new
close player (stop) ──► onStopped()       → abandon if not completed
leave player screen ──► onPlayerClosed()  → abandon if paused & not completed
app backgrounded ─────► onAppBackgrounded → abandon if paused & not completed
next app launch ──────► replayIfAbandoned → abandon from persisted record
```

### Exact fire conditions for `audio_session_abandoned`

It fires from whichever of these happens first for a given session, and **at most
once per session** (an internal `_ended` guard). It never fires if the session
completed (`onCompleted()` clears the record and sets the guard first).

1. **Switching to another track** — `PlayerProvider.play()` is called while a
   prior session is still active. The prior session is abandoned at its
   last-known position before the new one starts.
2. **Closing the player** — `PlayerProvider.stop()` (the player's close button,
   in any play state). On the completion path `stop()` is also called, but by
   then the session is already marked completed, so it's suppressed.
3. **Navigating away while paused** — the `PlayerView` is disposed (e.g. system
   back-gesture pop) while the session is **paused** and not completed. If audio
   is still **playing** when the screen is left, nothing fires: playback
   continues in the background and the session ends later via completion,
   background, or launch-replay.
4. **App backgrounding while paused** — `didChangeAppLifecycleState` →
   `paused`/`inactive`/`detached` while the session is paused and not completed.
   **Backgrounding while actively playing does NOT fire** — screen-off during a
   meditation is the normal case and must not be counted as a drop-off.
5. **Next app launch (reliability net)** — force-quit / swipe-away frequently
   sends no event (especially on iOS). The in-progress record (with the last
   persisted position) survives the kill; on the next launch
   `replayIfAbandoned()` fires the abandoned event from it and clears it.

### Reliability / persistence

- On `onStarted()` we write an in-progress record to
  `SharedPreferences` (key `incompleteAudioSession`):
  `{fileId, guide, durationMs, lastPositionMs, startMs}`.
- `onPositionUpdate()` refreshes `lastPositionMs` (and `durationMs` once the
  player reports a measured duration). Writes are **throttled** to ≤ once per
  ~3 s to avoid disk churn — we deliberately do **not** stream a ping per
  position tick.
- The record is **deleted** when the session completes (`onCompleted()`) or when
  a real-time abandoned event is fired. So launch-replay only fires for sessions
  that died without any clean end (true force-quit / OS-kill).
- **Android teardown hook:** in `AudioPlayerService.kt`, the swipe-away teardown
  path (`onTaskRemoved`, which runs only when not actively playing) pushes one
  final `updatePlaybackState` to Dart before stopping the service — guarded by
  `!isCompletionHandled` — so the Dart tracker's persisted position is as fresh
  as possible for the launch-replay. This piggybacks on the existing
  native→Dart position channel rather than firing Firebase from native code,
  matching how completion is reported.

### ⚠️ iOS ATT blindspot

These events ride on Firebase Analytics, which on iOS is disabled entirely when
the user denies App Tracking Transparency (since ~v3.6.17). So `started`,
`abandoned`, and `completed` are all logged for only the ~17% of iOS users who
allow tracking. **Completion rate is trustworthy on Android; on iOS (and any
platform-pooled cut) it's biased toward the allow-tracking minority.** This bias
is consistent across all three events, so the *ratio* (completed/started) is less
distorted than absolute counts — but split by platform when it matters.

### Known caveats (documented, accepted)

- Launch-replay attributes the abandonment to the launch time, not the original
  quit time. For drop-off *percent* this is fine (position is preserved); for
  event timestamps it's the next-open time.
- A session that is abandoned in real-time and then somehow resumed and completed
  could in principle log both `abandoned` and `completed`. In practice the
  real-time abandons happen on paths that also end the session (stop / switch /
  screen-dispose-while-paused), so this is rare. Completion rate
  (`completed / started`) is unaffected; drop-off analysis should treat
  `completed` as authoritative when both exist for one session.

## BigQuery sketch

```sql
-- completion rate
WITH starts AS (
  SELECT COUNT(*) n FROM `medito-9165c.analytics_451310720.events_*`
  WHERE event_name = 'audio_session_started'
),
completes AS (
  SELECT COUNT(*) n FROM `medito-9165c.analytics_451310720.events_*`
  WHERE event_name = 'audio_session_completed'
)
SELECT completes.n / starts.n AS completion_rate FROM starts, completes;

-- drop-off histogram
SELECT
  (SELECT value.int_value FROM UNNEST(event_params)
     WHERE key = 'percent_completed') AS pct,
  COUNT(*) sessions
FROM `medito-9165c.analytics_451310720.events_*`
WHERE event_name = 'audio_session_abandoned'
GROUP BY pct ORDER BY pct;
```
