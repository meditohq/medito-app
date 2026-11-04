# Health Connect export (Android)

When Health sync is enabled, every completed session is written to Health Connect as a
[`MindfulnessSessionRecord`](https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/MindfulnessSessionRecord)
of type `MINDFULNESS_SESSION_TYPE_MEDITATION`. Apps that read these records can use the
fields below to tell which meditation was completed.

| Field | Value |
|---|---|
| `startTime` / `endTime` | Start and end of the session (UTC offset). |
| `title` | Track name, e.g. `Body Scan`. Timer sessions use the timer's localized name (e.g. `Timer`, `Stopwatch`). `Medito` when the name isn't known (e.g. sessions completed before this was added). |
| `notes` | Semicolon-separated `key=value` ids, e.g. `trackId=abc123;fileId=def456`. Keys with no value are left out, and `notes` is null when there are none. |
| `metadata.clientRecordId` | `medito-<endEpochMs>`. Re-syncing the same session never creates a duplicate record. |

## Ids in `notes`

- `trackId`: the Medito track (meditation).
- `fileId`: the specific recording of that track (tracks can have several, e.g. different lengths or guides).

For tracks, both are stable ids from the Medito content API, so they're safe to store. Timer sessions have no content ids and use synthetic ones instead: `trackId=timer-<seconds>` and `fileId=timer-<mode>-<ms>` (e.g. `timer-countdown-600000`, `timer-stopwatch-0`). Parse `notes` by splitting
on `;` and then on the first `=`, and ignore keys you don't recognise: more keys may be added later.

This format is informational and may change between app versions; there is no backwards-compatibility
guarantee. Only Android exports this metadata today; Apple Health records are unchanged.
