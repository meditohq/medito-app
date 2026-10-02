# Release build log

Keep this file updated whenever a build number/version code is successfully uploaded to an external store track. Check it before rerunning release jobs so already-published builds are not uploaded again.

| Date | Version | Build / version code | Platform | Track(s) | Result | GitHub Actions run |
| --- | --- | ---: | --- | --- | --- | --- |
| 2026-10-01 | 2609.30.0 | 302467 | Android phone | Internal testing, Open testing | Uploaded successfully. Do not re-upload this phone APK/version code. | [36845278200](https://github.com/meditohq/medito-app/actions/runs/36845278200) |
| 2026-10-01 | 2609.30.0 | 302467 | iOS | TestFlight | Uploaded successfully and release tag created. | [36852107988](https://github.com/meditohq/medito-app/actions/runs/36852107988) |
| 2026-10-02 | 2609.30.0 | 302467 | Android phone | Internal testing | Re-upload rejected: `Cannot update a published APK`. Use `wear_only=true` for Wear-only retries. | [36983933785](https://github.com/meditohq/medito-app/actions/runs/36983933785) |
| 2026-10-02 | 2609.30.0 | 1000302467 | Wear OS | wear:qa | Upload rejected: `Track not found: wear:qa`. Wait for Play Console to expose/approve the Wear OS internal track before retrying this version code. | [36986690581](https://github.com/meditohq/medito-app/actions/runs/36986690581) |
| 2026-10-02 | 2609.30.0 | 1000302467 | Wear OS | wear:internal | Uploaded successfully (status completed). Tag `wear-2609.30.0` at e97af585. Do not re-upload this version code. | [36989197407](https://github.com/meditohq/medito-app/actions/runs/36989197407) |
| 2026-10-02 | 2610.2.0 | 302468 | Android phone | Internal testing | Uploaded successfully. Tag `2610.2.0` at 4ba60dc5 (includes develop merge). | [36990159827](https://github.com/meditohq/medito-app/actions/runs/36990159827) |
| 2026-10-02 | 2610.2.0 | 1000302468 | Wear OS | wear:internal | Uploaded successfully (status completed). | [36990159827](https://github.com/meditohq/medito-app/actions/runs/36990159827) |
| 2026-10-02 | 2610.2.0 | 302468 | iOS | TestFlight | Uploaded successfully. | [36990159827](https://github.com/meditohq/medito-app/actions/runs/36990159827) |

## Release checklist

- Before dispatching any store release, bump the app version/build number in the repo for the target release.
- After a successful store upload, create/update the git release tag so the tag matches the uploaded version/build.
- Record the uploaded build number/version code and the tag in this file before starting any retry.

## Notes

- Wear OS uses a separate APK with version code offset from the phone APK. For `2609.30.0+302467`, the Wear OS APK reported version code `1000302467` in the Play upload logs.
- If the phone APK/version code is already listed above as uploaded, do not rerun the normal Android upload for the same version code. Use the workflow's `wear_only=true` input for Wear-only retries.
- The Wear OS internal track is `wear:internal` (verified via the Play API track list 2026-10-02: `wear:internal`, `wear:beta`, `wear:production`). `wear:qa` does NOT exist for this app.
- Never add the phone APK (e.g. 302467) to a `wear:*` release in Play Console — it fails with "must require android.hardware.type.watch". Only the Wear APK (`1000000000 + build`) goes there.
- Wear-only builds made after a version's phone/iOS tag are tagged `wear-<version>` (that prefix keeps them out of the `N.N.N` previous-tag lookup).
- `wear_only=true` skips phone Play upload and, as of workflow commit `451b4743`, skips phone smoke/upgrade so a Wear-only retry is not blocked by phone-only smoke flakes.
