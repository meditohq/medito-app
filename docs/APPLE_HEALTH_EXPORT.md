# Apple Health export (iOS)

After Health authorization, completed tracks, repeated play-throughs and recorded
timer sessions are saved as HealthKit `mindfulSession` category samples. Start and
end dates describe the session; the category value is `notApplicable`.

Each new sample includes this metadata:

| Key | Value |
|---|---|
| `org.meditofoundation.title` | Track name or localized timer name (`Timer` / `Stopwatch`). Surrounding whitespace is removed; missing or blank names fall back to `Medito`. |
| `org.meditofoundation.trackId` | Medito track ID, omitted when missing or empty. |
| `org.meditofoundation.fileId` | Recording ID, omitted when missing or empty. |
| `HKMetadataKeySyncIdentifier` | `medito-<endEpochMs>`, matching Android's Health Connect client record ID. |
| `HKMetadataKeySyncVersion` | `1`. Re-exporting the same session does not create another sample. |
| `HKMetadataKeyWasUserEntered` | `false`, preserving automatic recording. |

The `HKMetadataKey…` entries above refer to Apple's HealthKit constants. Other
apps can read the custom keys from the sample's metadata dictionary; they do not
give the sample a dedicated title field in Apple Health.

Timer sessions use synthetic IDs: `trackId=timer-<seconds>` and
`fileId=timer-<mode>-<ms>`, just like Android. Background sounds and manually added
history entries are not exported.

Existing samples are not backfilled. Pending completions stored by older app
versions can still be exported with a `Medito` title and any IDs they contain.
The custom metadata format is informational and may change between app versions.

The app retains the health plugin for authorization and uses a small native
writer because the plugin's mindfulness write API does not accept custom
metadata. The writer uses HealthKit's
[sync identifier](https://developer.apple.com/documentation/healthkit/hkmetadatakeysyncidentifier)
and [sync version](https://developer.apple.com/documentation/healthkit/hkmetadatakeysyncversion)
for deduplication.
