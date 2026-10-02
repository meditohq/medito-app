# Release build log

Keep this file updated whenever a build number/version code is successfully uploaded to an external store track. Check it before rerunning release jobs so already-published builds are not uploaded again.

| Date | Version | Build / version code | Platform | Track(s) | Result | GitHub Actions run |
| --- | --- | ---: | --- | --- | --- | --- |
| 2026-10-01 | 2609.30.0 | 302467 | Android phone | Internal testing, Open testing | Uploaded successfully. Do not re-upload this phone APK/version code. | [36845278200](https://github.com/meditohq/medito-app/actions/runs/36845278200) |
| 2026-10-01 | 2609.30.0 | 302467 | iOS | TestFlight | Uploaded successfully and release tag created. | [36852107988](https://github.com/meditohq/medito-app/actions/runs/36852107988) |
| 2026-10-02 | 2609.30.0 | 302467 | Android phone | Internal testing | Re-upload rejected: `Cannot update a published APK`. Use `wear_only=true` for Wear-only retries. | [36983933785](https://github.com/meditohq/medito-app/actions/runs/36983933785) |
| 2026-10-02 | 2609.30.0 | 1000302467 | Wear OS | wear:qa | Upload rejected: `Track not found: wear:qa`. Wait for Play Console to expose/approve the Wear OS internal track before retrying this version code. | [36986690581](https://github.com/meditohq/medito-app/actions/runs/36986690581) |

## Notes

- Wear OS uses a separate APK with version code offset from the phone APK. For `2609.30.0+302467`, the Wear OS APK reported version code `1000302467` in the Play upload logs.
- If the phone APK/version code is already listed above as uploaded, do not rerun the normal Android upload for the same version code. Use the workflow's `wear_only=true` input for Wear-only retries.
- The current Wear OS internal track name in the release workflow is `wear:qa`, matching Google's documented Wear OS QA/internal track name. If Play returns `Track not found: wear:qa`, the Wear OS form factor/track is not available to the API yet.
- `wear_only=true` skips phone Play upload and, as of workflow commit `451b4743`, skips phone smoke/upgrade so a Wear-only retry is not blocked by phone-only smoke flakes.
