# Health Connect export (Android)

When Health sync is enabled, every completed session is written to Health Connect as a
[`MindfulnessSessionRecord`](https://developer.android.com/reference/kotlin/androidx/health/connect/client/records/MindfulnessSessionRecord)
of type `MINDFULNESS_SESSION_TYPE_MEDITATION`. Apps that read these records can use the
fields below to tell which meditation was completed.

| Field | Value |
|---|---|
| `startTime` / `endTime` | Start and end of the session (UTC offset). |
| `title` | Track name, e.g. `Body Scan`. `Medito` when the name isn't known (timer sessions, or sessions completed before this was added). |
| `notes` | Semicolon-separated `key=value` ids, e.g. `trackId=abc123;fileId=def456`. Keys with no value are left out, and `notes` is null when there are none. |
| `metadata.clientRecordId` | `medito-<endEpochMs>`. Re-syncing the same session updates this record instead of adding a duplicate. |

## Ids in `notes`

- `trackId`: the Medito track (meditation). Timer sessions use a synthetic id `timer-<seconds>`.
- `fileId`: the specific recording of that track (tracks can have several, e.g. different lengths or guides).

Both are stable ids from the Medito content API, so they're safe to store. Parse `notes` by splitting
on `;` and then on the first `=`, and ignore keys you don't recognise: more keys may be added later.

This format is informational and may change between app versions; there is no backwards-compatibility
guarantee. Only Android exports this metadata today; Apple Health records are unchanged.
