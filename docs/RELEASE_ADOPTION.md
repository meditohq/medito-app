# Release Adoption — version rollout curves (iOS vs Android)

**Companion to [`PAYWALL_ANALYTICS_TIMELINE.md`](./PAYWALL_ANALYTICS_TIMELINE.md).** That file says _when a version was cut_. This file says **when each version actually reached users, how fast it ramped, and the iOS↔Android skew** — derived empirically from BigQuery `app_info.version`, not from store-console rollout settings.

> **Why this exists:** the deploy pipeline ships to the Play **production** track and the App Store with **no rollout fraction in code** ([`release.yml`](./.github/workflows/release.yml)). The staged-rollout % lives only in Play Console / App Store Connect and is not version-controlled. So the *real* rollout curve — the share of live traffic on each version per day — is reconstructed from analytics here. For A/B work this is what you actually want: not the planned %, but the share of the experiment population that was running each build.

> ⚠️ **This is a dated SNAPSHOT.** Numbers below were computed **2026-09-01** over the window **2026-04-15 → 2026-08-31**. Current-share figures use **2026-08-30 (CUR)** — the newest table (`events_20260831`) is excluded from CUR because the freshest day keeps absorbing late events for a day or two. They go stale. The query at the bottom is the source of truth — re-run it to refresh. (Per the timeline doc's philosophy: trust the query, not cached numbers.)

> **🔑 FUNNEL BOUNDARY — the iOS ATT analytics fix (2026-06-23).** `2606.23.0` (cut 06-23) is the **first build with the iOS ATT analytics fix** (keeps first-party analytics on when ATT is denied; commit `31a676db`). Before it, iOS ATT-deniers were invisible in GA4 → all iOS funnel/onboarding/paywall metrics were biased toward the ~17% who allow tracking. **iOS analytics are only trustworthy from ~2026-06-23 onward**, ramping to full as `2606.23.0`/`2606.26.0` reach 100%. Confirmed recovering: iOS back-half onboarding completion went 16–18% (pre-fix builds) → ~79% (fixed builds), matching Android. **Treat 06-23 as a hard cohort cut for any iOS or pooled A/B read — do not pool pre- and post-06-23 iOS data.**

---

## The headline for A/B analysis

**iOS and Android are NOT on the same version at the same calendar date.** A date-only cohort mixes two different paywall/funnel builds.

- **iOS ramps fast** — a release crosses 50% of iOS DAU in **~2–3 days** (App Store phased release + fast iOS update behaviour).
- **Android ramps slow** — **~6+ days** to 50%, and a Play *staged rollout* can hold a build at a low % for weeks.
- **Net effect right now (CUR 2026-08-30):**
  - **Android**: 61% on `2608.27.0`, 25% on `2608.18.0`, 6% on `2607.28.0`; nothing else above 1%. **Mid-transition** — `2608.27.0` crossed 50% on 08-30 and was already at 73% on 08-31.
  - **iOS**: 92% on `2608.18.0`; then `2607.28.0` 4.3%, `2606.30.0` 1.2%. **`2608.27.0` has NOT reached iOS** — 3 users total across 08-27/08-28, i.e. internal/TestFlight only.

  → ⚠️ **The cross-platform convergence reported in the last snapshot is OVER.** `2608.27.0` is tagged in the repo (`chore: release 2608.27.0`, and `pubspec.yaml` is on `2608.27.0+302446`) and is taking over Android fast, but the iOS build of it has not reached the store — iOS is a full release behind, sitting on `2608.18.0`. **As of ~2026-08-29, platform is confounded with build again.** A date-only cohort from 08-29 onward pools Android-`2608.27.0` against iOS-`2608.18.0`. Split by `platform` **and** `app_info.version`. The clean converged period was roughly **2026-08-01 → 2026-08-20** (both platforms ≥90% on `2607.28.0`); after 08-21 both platforms are in back-to-back transitions.

**⚠️ Versions newer than the timeline doc exist.** The timeline doc's table stops at `26.5.19`. BigQuery shows the version scheme switched to `YYMM.build.patch` and many newer builds have since carried traffic (`2605.21.0`, `2606.5.0`, `2606.11.0`, `2606.17.0`, `2606.23.0`, `2606.26.0`, `2606.30.0`, `2607.5.0`, `2607.10.0`, `2607.20.3`, `2607.21.0`, `2607.24.0`, `2607.28.0`, `2608.18.0`, `2608.27.0`). The **two currently-dominant builds are undocumented in the timeline doc**: **`2608.18.0`** (iOS ~92%, Android ~25%) and **`2608.27.0`** (Android ~61% and climbing, iOS ~0%). `2607.28.0`, dominant at the last snapshot, is now a 4–6% tail on both. The tag `2608.25.0` exists in the repo but carries **no measurable traffic** — it never reached users on either platform. The ATT-fix build **`2606.23.0`** remains undocumented (now sub-1% on both). **The timeline doc needs a catch-up entry** — the `2607.2x` line's paywall/analytics deltas (native onboarding donation page, currency-localization fixes) and the ATT fix in `2606.23.0` aren't recorded there yet. What changed in `2608.18.0` / `2608.27.0` is not recorded anywhere; this file can only show that they shipped and how fast they rolled out, not what they altered.

**⚠️ 2026-06-08 Android is a data anomaly — do not use it.** Android DAU that day = **92,190** vs a 16,200 daily median — **5.7× normal** (iOS normal). Almost certainly a backfill / bot / duplicate-processing artefact in that daily table. It remains the **only** anomalous day detected in this run (re-confirmed 2026-09-01 — this is a live detection, not a carried-over note; nothing anomalous in the 08-12 → 08-31 extension). Current-share figures below are computed on **2026-08-30** (CUR — a clean day, Android 15,152 / iOS 6,148 DAU). Anomalous days are excluded from all peak/milestone/weekly figures below. Exclude 2026-06-08 Android from any analysis until explained.

---

## Modern releases — arrival & rollout speed

`hit 10%` / `hit 50%` = first day the version reached that share of its platform's DAU. `—` = never reached it within the window (still ramping or held on staged rollout). `share 08-30` = share of platform DAU on the last clean day (CUR).

### Android

| Version     | First seen | hit 10%    | hit 50%    | Peak share (day)   | share 08-30 |
| ----------- | ---------- | ---------- | ---------- | ------------------ | ----------- |
| `2606.23.0` ⭐ | 2026-06-21 | 2026-06-24 | 2026-06-25 | 61% (06-26)        | 0.1%        |
| `2606.26.0` | 2026-06-23 | 2026-06-27 | 2026-06-28 | 86% (07-06)        | 0.8%        |
| `2606.30.0` | 2026-06-30 | 2026-07-09 | —          | 41% (07-09)        | 0.1%        |
| `2607.5.0`  | 2026-07-05 | 2026-07-10 | 2026-07-11 | 85% (07-17)        | 0.8%        |
| `2607.20.3` | 2026-07-18 | 2026-07-21 | 2026-07-22 | 73% (07-24)        | 0.3%        |
| `2607.24.0` | 2026-07-21 | 2026-07-25 | 2026-07-26 | 78% (07-29)        | 0.6%        |
| `2607.28.0` | 2026-07-27 | 2026-07-31 | 2026-08-01 | 91% (08-17)        | 6.3%        |
| `2608.18.0` | 2026-08-17 | 2026-08-21 | 2026-08-22 | 82% (08-27)        | 24.7%       |
| `2608.27.0` | 2026-08-25 | 2026-08-28 | 2026-08-30 | 73% (08-31)        | **61.4%**   |

⭐ = first build with the iOS ATT analytics fix (matters for iOS; Android was never affected, listed here for the rollout record). Android takes ~5–6 days to 50%. `2606.30.0` never fully took over on Android (peaked ~41% on 07-09) — it was leapfrogged by `2607.5.0` (peaked ~85%). The `2607.2x` line then rolled through fast: `2607.20.3` (~73%) → `2607.24.0` (~78%) → `2607.28.0`, which peaked at **91% on 08-17** — the highest Android share in the window — before being displaced in turn. `2608.18.0` took over next (10% on 08-21, 50% on 08-22, peak 82% on 08-27), and was itself displaced only ~a week later by **`2608.27.0`**, which is still ramping at CUR (61% on 08-30, 73% on 08-31) and has not yet peaked. Two full Android turnovers inside two weeks — 08-17 → 08-31 contains three different dominant builds, so **do not treat late August as one Android cohort.** Android skipped `2607.21.0` (iOS-only). `2608.27.0` matched `2607.28.0`'s pace: 3 days to 10%, 5 days to 50%. `26.5.19` (0.6% at CUR), `2605.21.0`, `2606.11.0` and `2606.17.0` have aged out of this table.

### iOS

| Version     | First seen | hit 10%    | hit 50%    | Peak share (day)   | share 08-30 |
| ----------- | ---------- | ---------- | ---------- | ------------------ | ----------- |
| `2606.11.0` | 2026-06-11 | 2026-06-18 | 2026-06-19 | 90% (06-23)        | 0.1%        |
| `2606.23.0` ⭐ | 2026-06-23 | 2026-06-24 | 2026-06-25 | 83% (06-26)        | 0.0%        |
| `2606.26.0` | 2026-06-26 | 2026-06-27 | 2026-06-28 | 89% (06-30)        | 0.2%        |
| `2606.30.0` | 2026-06-30 | 2026-07-02 | 2026-07-03 | 96% (07-19)        | 1.2%        |
| `2607.20.3` | 2026-07-20 | 2026-07-22 | 2026-07-23 | 54% (07-23)        | 0.1%        |
| `2607.21.0` | 2026-07-21 | 2026-07-23 | 2026-07-25 | 89% (07-27)        | 0.4%        |
| `2607.24.0` | 2026-07-24 | 2026-07-29 | 2026-07-30 | 65% (07-30)        | 0.2%        |
| `2607.28.0` | 2026-07-28 | 2026-07-31 | 2026-08-01 | 95% (08-21)        | 4.3%        |
| `2608.18.0` | 2026-08-18 | 2026-08-22 | 2026-08-23 | 93% (08-31)        | **92.0%**   |
| `2608.27.0` | 2026-08-27 | —          | —          | 0.0% (08-27)       | 0.0%        |

⭐ = first build with the iOS ATT analytics fix (commit `31a676db`) — see the funnel-boundary callout up top. iOS normally takes ~2–3 days to 50%. `2606.30.0` reached 96% and held through mid-July; iOS then moved through the `2607.2x` line — `2607.20.3` (~54%) → `2607.21.0` (~89%) → `2607.24.0` (~65%, never dominated) → `2607.28.0`, which peaked at **95% on 08-21**. **`2608.18.0` is the current iOS build** — note its ramp was slower than the iOS norm: first seen 08-18 but only a handful of users until 08-22 (App Store phased release didn't open until then), so it was 5 days from first sighting to 50%, or ~1 day once the phased release actually started. It is still at its peak (93% on 08-31).

**⚠️ `2608.27.0` has not shipped to iOS.** Three users total (08-27/08-28) — internal or TestFlight, not a public release. The tag exists in the repo and Android is already ~73% on it, so iOS is a whole release behind; either the App Store build is still in review/unsubmitted, or it was never submitted. Worth confirming in App Store Connect. `2606.5.0`, `26.5.19` and `2605.21.0` have aged out of this table.

---

## Weekly dominant version (calendar → version map)

Quickest way to pick a clean A/B window: find the week, read off which build the platform was actually running. Top-3 share of platform DAU, weeks Monday-anchored.

### Android

| Week of    | #1                | #2                 | #3            |
| ---------- | ----------------- | ------------------ | ------------- |
| 2026-05-25 | `26.5.19` 81%     | `26.5.13` 7%       | `26.4.28` 2%  |
| 2026-06-01 | `26.5.19` 83%     | `2605.21.0` 5%     | `26.5.13` 2%  |
| 2026-06-08 | `26.5.19` 47%     | `2605.21.0` 42%    | `26.5.13` 1%  _(06-08 anomaly excluded)_ |
| 2026-06-15 | `2606.17.0` 34%   | `2605.21.0` 29%    | `2606.11.0` 21% |
| 2026-06-22 | `2606.17.0` 42%   | `2606.23.0` 29%    | `2606.26.0` 14% |
| 2026-06-29 | `2606.26.0` 82%   | `2606.17.0` 4%     | `2606.23.0` 3% |
| 2026-07-06 | `2606.26.0` 52%   | `2607.5.0` 20%     | `2606.30.0` 17% |
| 2026-07-13 | `2607.5.0` 82%    | `2606.26.0` 6%     | `26.5.19` 2%  |
| 2026-07-20 | `2607.20.3` 43%   | `2607.5.0` 31%     | `2607.24.0` 13% |
| 2026-07-27 | `2607.24.0` 56%   | `2607.28.0` 25%    | `2607.20.3` 5% |
| 2026-08-03 | `2607.28.0` 84%   | `2607.24.0` 4%     | `2607.5.0` 2% |
| 2026-08-10 | `2607.28.0` 89%   | `2607.5.0` 2%      | `2607.24.0` 1% |
| 2026-08-17 | `2607.28.0` 67%   | `2608.18.0` 24%    | `2607.5.0` 1% |
| 2026-08-24 | `2608.18.0` 68%   | `2608.27.0` 16%    | `2607.28.0` 9% |
| 2026-08-31 | `2608.27.0` 73%   | `2608.18.0` 15%    | `2607.28.0` 5% _(1 day only)_ |

### iOS

| Week of    | #1                | #2                 | #3            |
| ---------- | ----------------- | ------------------ | ------------- |
| 2026-05-25 | `26.5.19` 92%     | `26.5.13` 2%       | `26.4.28` 1%  |
| 2026-06-01 | `26.5.19` 53%     | `2605.21.0` 41%    | `26.5.13` 1%  |
| 2026-06-08 | `2606.5.0` 68%    | `2605.21.0` 24%    | `26.5.19` 3%  |
| 2026-06-15 | `2606.5.0` 54%    | `2606.11.0` 39%    | `26.5.19` 1% |
| 2026-06-22 | `2606.11.0` 43%   | `2606.23.0` 36%    | `2606.26.0` 13% |
| 2026-06-29 | `2606.26.0` 51%   | `2606.30.0` 40%    | `2606.23.0` 3% |
| 2026-07-06 | `2606.30.0` 93%   | `2606.26.0` 2%     | `2606.23.0` 1% |
| 2026-07-13 | `2606.30.0` 95%   | `2606.26.0` 1%     | `2606.23.0` 0% |
| 2026-07-20 | `2606.30.0` 45%   | `2607.21.0` 30%    | `2607.20.3` 21% |
| 2026-07-27 | `2607.21.0` 39%   | `2607.28.0` 28%    | `2607.24.0` 26% |
| 2026-08-03 | `2607.28.0` 91%   | `2606.30.0` 3%     | `2607.21.0` 2% |
| 2026-08-10 | `2607.28.0` 94%   | `2606.30.0` 2%     | `2607.21.0` 1% |
| 2026-08-17 | `2607.28.0` 84%   | `2608.18.0` 11%    | `2606.30.0` 1% |
| 2026-08-24 | `2608.18.0` 89%   | `2607.28.0` 7%     | `2606.30.0` 1% |
| 2026-08-31 | `2608.18.0` 93%   | `2607.28.0` 4%     | `2606.30.0` 1% _(1 day only)_ |

> Read the divergence: week of 06-01, Android is 83% `26.5.19` while iOS is split `26.5.19` 53% / `2605.21.0` 41% — mid-transition on iOS, not yet on Android. Same calendar week, different code mix per platform. By the week of 07-13 the split was a whole build apart (Android 82% `2607.5.0` vs iOS 95% `2606.30.0`) with **Android ahead**. The week of 07-27 is the messiest in the window — three-way splits on both platforms (Android `2607.24.0` 56% / `2607.28.0` 25%, iOS `2607.21.0` 39% / `2607.28.0` 28% / `2607.24.0` 26%) — **do not use it as a single cohort on either platform.** By the week of 08-03 both platforms have converged on `2607.28.0` (Android 84%, iOS 91%), the first genuinely clean cross-platform week in the whole window — tightening further the week of 08-10 (Android 89%, iOS 94%). **That convergence lasted two weeks and then broke.** Week of 08-17 both platforms are mid-transition off `2607.28.0` onto `2608.18.0`; week of 08-24 they briefly agree again on `2608.18.0` (Android 68%, iOS 89%) but Android is already 16% onto `2608.27.0`; and by 08-31 they are a full release apart — **Android 73% `2608.27.0` vs iOS 93% `2608.18.0`.** The only genuinely clean pooled window in the whole dataset is **08-01 → 08-20**. Android skipped `2607.21.0` entirely — so a `2607.21.0`-vs-`2607.24.0` cohort split is meaningful on iOS but not on Android. The week of 06-22 also straddles the 06-23 ATT-fix boundary (`2606.23.0`) — split it by version, don't read it as one cohort.

---

## How to use this for A/B tests

1. **Pick your experiment date window** (from the timeline doc / experiment config).
2. **Per platform**, read the weekly table to see which build(s) dominated that window. If two builds with different funnel behaviour split the window (e.g. a transition week), either restrict to the dominant build or split the cohort by `app_info.version`.
3. **Never pool iOS + Android by date** — they're on different builds. Either analyse per platform, or confirm both platforms ran the same build for your window (rare during the first ~week of any release).
4. **Cross-check against the timeline doc's funnel boundaries.** A version reaching 50% is also when its funnel/analytics changes reach half the population — e.g. the 26.5.19 onboarding-funnel change hit 50% of iOS on 05-21 but 50% of Android only on 05-24.
5. **Exclude 2026-06-08 Android** until the spike is explained.

---

## Reusable queries — refresh this doc

### 1. Raw daily distinct users per version per platform (the source pull)

```sql
-- Edit the date suffixes to widen/move the window.
SELECT
  PARSE_DATE('%Y%m%d', event_date) AS day,
  platform,
  app_info.version AS app_version,
  COUNT(DISTINCT user_pseudo_id) AS users
FROM `medito-9165c.analytics_451310720.events_*`
WHERE _TABLE_SUFFIX BETWEEN '20260415' AND '20260831'
  AND platform IN ('IOS', 'ANDROID')
  AND app_info.version IS NOT NULL
GROUP BY 1, 2, 3
ORDER BY 1, 2, users DESC
```

### 2. Daily share per version (rollout curve, computed in SQL)

```sql
WITH daily AS (
  SELECT
    PARSE_DATE('%Y%m%d', event_date) AS day,
    platform,
    app_info.version AS app_version,
    COUNT(DISTINCT user_pseudo_id) AS users
  FROM `medito-9165c.analytics_451310720.events_*`
  WHERE _TABLE_SUFFIX BETWEEN '20260415' AND '20260831'
    AND platform IN ('IOS', 'ANDROID')
    AND app_info.version IS NOT NULL
  GROUP BY 1, 2, 3
)
SELECT
  day, platform, app_version, users,
  SUM(users) OVER (PARTITION BY day, platform) AS platform_dau,
  ROUND(users / SUM(users) OVER (PARTITION BY day, platform) * 100, 1) AS share_pct
FROM daily
WHERE app_version LIKE '26.%' OR app_version LIKE '260%'   -- modern scheme only; drop to see all
ORDER BY platform, day, share_pct DESC
```

### 3. Which builds dominated a specific A/B window (paste your experiment dates)

```sql
DECLARE win_start STRING DEFAULT '20260515';   -- experiment start (YYYYMMDD)
DECLARE win_end   STRING DEFAULT '20260622';   -- experiment end

WITH d AS (
  SELECT platform, app_info.version AS app_version,
         COUNT(DISTINCT user_pseudo_id) AS users
  FROM `medito-9165c.analytics_451310720.events_*`
  WHERE _TABLE_SUFFIX BETWEEN win_start AND win_end
    AND platform IN ('IOS', 'ANDROID') AND app_info.version IS NOT NULL
  GROUP BY 1, 2
)
SELECT platform, app_version, users,
       ROUND(users / SUM(users) OVER (PARTITION BY platform) * 100, 1) AS share_pct
FROM d
QUALIFY share_pct >= 1.0
ORDER BY platform, users DESC
```

> Note: distinct-user counts across a multi-day window don't sum to 100% the way a single day does (a user can appear on several versions if they update mid-window). For clean rollout curves use query 2 (per-day). Query 3 is a "who was in this experiment" rough mix.

---

## Keep this updated

Re-run query 1, drop the CSV through the same processing, and refresh the tables + snapshot date whenever you're about to lean on it for an analysis. The structural facts (a new version shipped, its funnel deltas) belong in [`PAYWALL_ANALYTICS_TIMELINE.md`](./PAYWALL_ANALYTICS_TIMELINE.md); the adoption curves belong here.
