# Shorebird Code-Push — Migration Plan & Spike Findings

_Spike date: 2026-07-01. Goal: replace the donation webview with a native Dart view that we can A/B test and hot-fix over-the-air via Shorebird `patch` (no App Store / Play review), by swapping the release pipeline from `flutter build` to `shorebird release`._

> **Status: spike complete — all open questions resolved.** No pipeline code changed yet. Items marked **[verify]** are documented-but-unconfirmed and must be checked with a test build before production reliance.

---

## TL;DR

- **Feasible with no blocker.** Release CI builds Flutter **3.41.6** (`subosito/flutter-action` in `.github/workflows/release.yml`), and Shorebird supports 3.41.6 exactly. The usual killer (unsupported Flutter version) does not apply.
- **Contained change, not a rewrite.** Swap the compile in **2 places** (Android in `release.yml`, iOS in `ios/fastlane/Fastfile`), add `shorebird.yaml`, add a new `shorebird-patch.yml`, add the `SHOREBIRD_TOKEN` CI secret (✅ already added). **All signing, uploads, and existing secrets stay identical.**
- **The native donation view is patchable** (Dart-only, on top of already-shipped `flutter_stripe` + `webview_flutter`) — with one analytics landmine that must be handled (see §7).
- **Version keying: NO fix needed (corrected 2026-07-01).** The iOS app already tracks the pubspec version — `ios/Runner/Info.plist` uses `$(FLUTTER_BUILD_NAME)`/`$(FLUTTER_BUILD_NUMBER)`, so the `3.1.10`/`30045` in `project.pbxproj` are **dead settings** for the app. Build numbers already increment +1 per release via the `release` skill. Shorebird keying works as-is; the only real pre-work is CI wiring (§6).

---

## 1. How Shorebird changes the pipeline

Shorebird replaces the *compile step* only. It does not touch signing, upload, or app architecture.

| Subsystem | Today | With Shorebird |
|---|---|---|
| Android build (`release.yml` android-build, ~L146) | `flutter build apk --flavor prod --release …` | `shorebird release android --flavor prod -- <same dart-defines>` |
| iOS build (`ios/fastlane/Fastfile` beta L52-59 / release L96-104) | `flutter build ios --release --no-codesign` → `build_app` (gym) | `shorebird_release(platform: "ios")` action **in place of** `build_app` |
| OTA updates | _n/a_ | **new** `shorebird patch` via a new `shorebird-patch.yml` workflow |

### Stays byte-for-byte identical
- **iOS signing:** fastlane `match` (readonly, `meditohq/fastlane-certificates`), ASC API key, `upload_to_testflight` / `upload_to_app_store`.
- **iOS Xcode selection:** `maxim-lobanov/setup-xcode` + the `before_all` `xcode-select -p` derivation (the iOS 26 SDK-mandate fix) — still load-bearing, unchanged.
- **Android signing:** Gradle `signingConfigs.release` ← `keystore.properties` + `meditokey.jks`; Play upload via `PLAY_STORE_CONFIG_JSON`, tracks/promote logic.
- **All existing GitHub secrets**, the Maestro smoke/upgrade-test jobs (stay on plain Flutter — throwaway artifacts), and `ci-develop.yml` / `smoke-test.yml`.

---

## 2. Resolved: iOS signing (match + `MeditoWidgetExtension`) — **use Approach A**

**Decision: use the `shorebird_release` fastlane action from `fastlane-plugin-shorebird`, in place of `build_app`/gym. Do NOT use `--no-codesign` + gym (Approach B).**

Why: this is Shorebird's officially documented Fastlane path, and it is exactly the fix Shorebird shipped for the app-extension signing failure (issue [#2939](https://github.com/shorebirdtech/shorebird/issues/2939), resolved 2025-06-13). The plugin:
- reads `MATCH_PROVISIONING_PROFILE_MAPPING` from the lane context (populated by `sync_code_signing`),
- **auto-generates** a `signingStyle=manual` `ExportOptions.plist` containing **all** match profiles, and sets `manageAppVersionAndBuildNumber=false`,
- passes it to `shorebird release ios --export-options-plist …`, emits `build/ios/ipa/*.ipa`, and sets `IPA_OUTPUT_PATH` so `upload_to_*` finds the ipa with no `ipa:` param.

`shorebird release ios` internally runs `flutter build ipa` (archive **and** export), so with codesigning on it produces a signed `.ipa` directly — there is no archive-only handoff for gym, which is why Approach B is not a documented/supported flow (and disables `shorebird preview`).

**Consequences for us:**
- Our committed `exportOptions.plist` (`signingStyle=automatic`, no map) becomes irrelevant for this flow — the plugin writes its own manual plist from match. Our existing per-target manual `update_code_signing_settings` work stays compatible.
- **Both targets must be in the match mapping.** `sync_code_signing` must run for **both** the Runner (`org.meditofoundation`) **and** the `MeditoWidgetExtension` bundle ID **[verify exact widget bundle id in project.pbxproj]**, or we hit the #2939 error (`"MeditoWidgetExtension.appex" requires a provisioning profile`).
- **Add the plugin:** it is not installed yet → `fastlane add_plugin shorebird` (pulls the current, post-fix version; no version archaeology needed).

Recommended lanes (adapt bundle IDs / version args):
```ruby
lane :release_shorebird do
  setup_ci
  sync_code_signing(type: "appstore", app_identifier: "org.meditofoundation", readonly: true)
  sync_code_signing(type: "appstore", app_identifier: "<widget extension bundle id>", readonly: true)   # [verify]
  shorebird_release(platform: "ios", args: "--flavor prod --flutter-version=3.41.6 --build-name=#{v} --build-number=#{b}")
  app_store_connect_api_key(is_key_content_base64: true, in_house: false)
  upload_to_testflight   # reads IPA_OUTPUT_PATH automatically
end

lane :patch_shorebird do
  setup_ci
  shorebird_patch(platform: "ios", args: "--flavor prod --flutter-version=3.41.6 --release-version=latest")
end
```

---

## 3. Resolved: Android — APK vs AAB + Play App Signing

- **APK-artifact releases are patchable.** `--artifact` accepts `aab` (default) and `apk`; `--artifact apk` yields *both* the `.apk` and `.aab` from one patchable release. No AAB-only restriction on code push.
- **Play App Signing is orthogonal to patches.** Docs are silent on it, but the mechanism makes it a non-issue: Shorebird keys patch matching off a byte-identical `libapp.so` + its own patch-signing keypair, **not** the outer APK/AAB certificate that Play re-signs. **[verify with a test — docs don't state it explicitly; medium confidence.]**
- **Hard rule (load-bearing for our CI):** whatever `versionCode`/`versionName` the Shorebird build emits **must** be what lands on Play. _"Modifying the version code or build number inside the Google Play Console during or after upload will cause patch resolution to fail for that release."_ Do not let fastlane or Play Console mutate them post-build.
- **Recommendation:** move Play upload from APK → **AAB** (`shorebird release android` default; replace `fastlane upload_apk` with `upload_to_play_store(aab: …)`). For installable test builds use `shorebird preview` and/or `shorebird releases get-apks --release-version <v>` (extracts an APK from an AAB release). Keep `--artifact apk` only if a raw QA sideload APK is still wanted.
- **Enable Patch Signing** (`--public-key-path` on release, `--private-key-path` on patch) so patch integrity is under our control.

---

## 4. Resolved: R8 / ProGuard / obfuscation

- **No Shorebird keep rules needed.** The updater is a Rust static lib inside the engine `.so` — invisible to R8 (which only shrinks/renames JVM bytecode). Leave `proguard-rules.pro` as-is for our own needs.
- **`minifyEnabled=true` is fine but requires reproducible builds.** R8 rewrites `.dex`; Shorebird assumes byte-for-byte reproducible builds. Non-deterministic R8 output → false native-diff warnings on patch. **[verify]** by building twice and diffing, and by running one release→patch cycle in CI and watching for the `.dex` native-diff warning. Watch for any Gradle plugin that injects per-build IDs (e.g. Sentry mapping) — a known reproducibility breaker.
- **`--obfuscate` is auto-matched on patch** — do NOT add/remove it on `patch` (a mismatch balloons the patch). Pass `--obfuscate --split-debug-info=./symbols` on **release**; pass `--split-debug-info` consistently on patch too (docs don't confirm it's auto-matched like `--obfuscate`).

---

## 5. Resolved: Flavors

- `shorebird init` **auto-detects** our `dev`/`prod` flavors, creates one Shorebird app per flavor, and writes the `app_id` + `flavors:` map into `shorebird.yaml` automatically. Format:
  ```yaml
  app_id: <prod-or-first-flavor-uuid>   # required; overwritten per-flavor at build time
  flavors:
    dev: <dev-uuid>
    prod: <prod-uuid>
  ```
- Pass `--flavor prod` (+ `--target` if a non-default entrypoint) on **both** release and patch, using the exact Gradle flavor names.
- **[verify]** the detected Android flavor names match our single `flavorDimensions "default"` `dev`/`prod` (Shorebird has had historical multi-dimension flavor bugs — ours is single-dimension so likely fine).

---

## 6. Required pre-work BEFORE the first `shorebird release`

1. **iOS version keying — NO fix needed (corrected 2026-07-01).** An earlier draft of this doc claimed iOS was frozen at `3.1.10` and had to be repointed at `$(FLUTTER_BUILD_*)`. That was a **misread of `project.pbxproj` without checking the Info.plist.** In fact `ios/Runner/Info.plist` already sets `CFBundleShortVersionString = $(FLUTTER_BUILD_NAME)` and `CFBundleVersion = $(FLUTTER_BUILD_NUMBER)`, so the **main app already ships the pubspec version** (`2606.x` / `+build`). The `MARKETING_VERSION = 3.1.10` / `CURRENT_PROJECT_VERSION = 30045` in `project.pbxproj` are **dead settings** for the Runner target (its Info.plist never references them). Shorebird's iOS release-version therefore already equals the pubspec version and is unique per release — **nothing to change.**
   - _Cosmetic caveat, NOT a Shorebird blocker:_ the `MeditoWidgetExtension` Info.plist uses `$(MARKETING_VERSION)`/`$(CURRENT_PROJECT_VERSION)`, so the widget ships the hardcoded `3.1.10/30045`, mismatched from the app's `2606.x`. It ships today regardless, and Shorebird keys off the **main app**, not the extension. Syncing the widget (would need the widget target to include `Generated.xcconfig` + a TestFlight validation) is optional and out of scope for Shorebird adoption.
2. **Unique build number per release — already handled.** The `release` skill (`.claude/skills/release/SKILL.md`, step 4) increments `+build` by exactly 1 on every release (`prepare_release.sh` preserves it; the skill bumps it afterward). Do **NOT** also change `prepare_release.sh` — that would double-bump. Each release already gets a unique, increasing build number on both platforms, so no change is needed.
3. **Add `fastlane-plugin-shorebird`** (`fastlane add_plugin shorebird`) — not installed yet.
4. **Enable Patch Signing** — generate the keypair, `--public-key-path` on release, `--private-key-path` on patch (store the private key as a CI secret).
5. **Fence off local build paths.** `build_all.sh` / `build_ios.sh` / the root + android beta/production fastlane lanes still do plain `flutter build` — a store build cut through them is **non-patchable** and silently breaks OTA for that version. CI (`release.yml`) is the real release path (confirmed) → block or convert the local paths.
6. **Reconcile the Flutter provider in CI.** Remove `subosito/flutter-action` as the *build* provider in the release-producing jobs (keep it only for `pub get`/`build_runner`/pigeon tooling and the smoke/upgrade-test jobs) so only Shorebird's Flutter builds the store artifact. Pin `--flutter-version=3.41.6` on every release AND patch.

---

## 7. The donation-view goal — patchable, with an analytics landmine

**Verdict: YES, a native pure-Dart donation view (and its A/B variants) ships via `shorebird patch` with no store review**, on the condition it adds **zero new native dependency**:
- `flutter_stripe 12.6.0` + `webview_flutter` are already compiled in; the payment stack (`PaymentUIController`, `paymentConfigProvider`, `DonationApiService`) is already Dart.
- **Keep `webview_flutter` installed-but-dead** so the cutover is a pure patch — removing a plugin is itself a native change (release-only).
- Non-patchable (→ full release): bumping `flutter_stripe`, any new Pay/IAP/native plugin, new URL scheme / Apple Pay entitlement / Google Pay manifest metadata, any new runtime permission.

**⚠️ Analytics landmine (ties to donate3/4/5 + Stripe LTV):** the A/B **variant bucketing + hero copy + price ladders currently live server-side on the paywall website**, reaching Dart only through the **webview JS bridge**. A native view **loses that channel.** So variant assignment must be **re-sourced from a Dart-reachable HTTP JSON endpoint** (NOT native Firebase RemoteConfig — that's a native change and not patchable), and it MUST keep emitting the identical `experiment_id` / `experiment_variant` into the same Firebase events + Stripe PaymentIntent metadata — or the BigQuery paywall-experiment and Stripe LTV joins break at cutover.

_Bonus: Shorebird's own staged rollout is DIY on top of "tracks" + a per-device group number — which our existing remote-config infra could drive directly._

---

## 8. Patch safety (operational)

- **Native/asset diffs block by default** (`--allow-native-diffs`/`--allow-asset-diffs` off) — you can't accidentally OTA a native change.
- **Staging → stable:** `shorebird patch … --track staging`, validate with `shorebird preview --track staging`, then promote (Console or `shorebird patches set-track … --track stable`).
- **Rollback:** manual (Console/CLI) + automatic (a patch that fails to load is marked bad and the device auto-reverts on next launch).
- **Timing:** patches download in the background and apply on **next app restart** — never mid-session. **Offline meditation is unaffected** (app runs on the installed version; updater retries next launch).

---

## 9. Open items to verify with a test build

1. Multi-target `provisioningProfiles` dict (Runner + widget) — docs only show a single bundle ID; confirm the generated plist has both.
2. `sync_code_signing` populates `MATCH_PROVISIONING_PROFILE_MAPPING` for both bundle IDs in one lane.
3. Play App Signing does not break patch resolution (docs silent — confirm via a live patch, or Shorebird support/Discord).
4. R8/`minifyEnabled` reproducibility — no false native-diff on a release→patch cycle.
5. Whether `shorebird patch ios` needs the same match/export-options setup as release (demo `patch` lane omits them).
6. Confirm the exact widget-extension bundle ID and that match has a profile for it.

---

## 10. Cost / plan
Shorebird is a paid service with a free tier (patch volume + MAU limits). Confirm the tier covers Medito's MAU and expected patch cadence before relying on it in production.

---

## 11. CI wiring — implemented 2026-07-01 (needs `shorebird init` + a dry-run before it works)

**Files changed (working tree, not committed):**
- `.github/workflows/release.yml` — Android build → `shorebird release android --artifact apk` (keeps the existing APK path + Play upload unchanged); iOS deploy → bundler-managed fastlane + Shorebird setup + `SHOREBIRD_TOKEN`.
- `ios/fastlane/Fastfile` — `build_app`/gym → `shorebird_release` (Approach A); new `patch` lane; dart-defines passed as **shorebird-level flags (no `--`)** so the plugin's appended `--export-options-plist` stays valid.
- `ios/fastlane/Pluginfile` — declares `fastlane-plugin-shorebird`.
- `.github/workflows/shorebird-patch.yml` — new dispatch-only OTA patch (android + ios; staging→stable; release version derived from the checked-out ref).

**Fixed from the adversarial review:** iOS arg-ordering blocker (dropped `--`), plugin loading (bundler, not bare `gem install`), removed `--obfuscate` on patch (Shorebird auto-matches it), `release_version=latest` now derives from the ref, APK-path sanity check.

### Prerequisite runbook (you run these — interactive / your environment)
1. **`shorebird init`** in `medito_new/` — authenticate with your API key, **not** `shorebird login` (that flow is gone; auth is API-key only). Export the key first so the CLI picks it up: `export SHOREBIRD_TOKEN=<your key>`. Creates `shorebird.yaml` (one app per flavor: dev/prod) and adds it to `pubspec.yaml` `flutter: assets:`. **Commit both** (without the assets entry, shipped apps can't fetch patches). Note: GitHub secrets are write-only, so if you don't have the key value locally, mint another at console.shorebird.dev (multiple keys are fine).
2. **⚠️ Resolve the flavor mismatch (the important one).** Android builds `--flavor prod`; iOS builds a single flavorless `Runner` scheme. A flavored `shorebird.yaml` resolves Android's `prod` from the `flavors:` map, but flavorless iOS uses the **top-level `app_id`**, which `init` defaults to the *first* flavor (likely `dev`). **Set the top-level `app_id` to the `prod` app's id** so iOS resolves to the prod Shorebird app. Verify each platform with `shorebird release <platform> --dry-run` before a real run.
3. **`cd ios && fastlane add_plugin shorebird`** — wires `ios/Gemfile` + `Pluginfile` for bundler. Commit `ios/Gemfile`, `ios/Gemfile.lock`, `ios/fastlane/Pluginfile`.
4. **`SHOREBIRD_TOKEN`** = a console API key (✅ added — confirm it's the API key, not a login token).
5. **(Recommended before production patches) Patch signing.** Generate a keypair; add `--public-key-path` on release + `--private-key-path` (secret) on patch. Enabling it requires a NEW release — can't be retrofitted.

### Validation (dry-run before trusting it)
- Dispatch `release.yml` with `ios_testflight=true` + `android_internal=true` (NOT production). Confirm: Android APK at the expected path (the `ls` line); iOS signs BOTH Runner + MeditoWidgetExtension (watch for the #2939 appex error); both appear as a Shorebird release in the console.
- Then dispatch `shorebird-patch.yml` (`--ref <same tag>`, `track=staging`), validate with `shorebird preview --track staging`, then promote to stable.

### Still to verify on that first dry-run (`[VERIFY]` markers in the code)
- iOS: the generated ExportOptions.plist covers BOTH bundle IDs (log `MATCH_PROVISIONING_PROFILE_MAPPING`); if widget signing fails, pass explicit `export_options:` to `shorebird_release`.
- iOS patch: whether `shorebird patch ios` needs the match/signing the lane sets up (the official demo omits it) — a `--dry-run` tells.
- Android APK output path under `--flavor prod` (the `ls` line surfaces it on run 1).

---

## Sources
Shorebird CLI 1.6.110 (`shorebird --help`, `shorebird flutter versions list`), docs.shorebird.dev (release, patch, ci/fastlane, flavors, staging, rollback, play-store, app-store guides), `shorebirdtech/fastlane-plugin-shorebird`, `shorebirdtech/fastlane_demo`, issue #2939. Full spike transcripts: workflow runs `wf_e603b05f-d49` (pipeline map) and `wf_54494406-902` (doc research) + iOS signing research agent.
