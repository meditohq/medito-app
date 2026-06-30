# Release Adoption — version rollout curves (iOS vs Android)

**Companion to [`PAYWALL_ANALYTICS_TIMELINE.md`](./PAYWALL_ANALYTICS_TIMELINE.md).** That file says _when a version was cut_. This file says **when each version actually reached users, how fast it ramped, and the iOS↔Android skew** — derived empirically from BigQuery `app_info.version`, not from store-console rollout settings.

> **Why this exists:** the deploy pipeline ships to the Play **production** track and the App Store with **no rollout fraction in code** ([`release.yml`](./.github/workflows/release.yml)). The staged-rollout % lives only in Play Console / App Store Connect and is not version-controlled. So the *real* rollout curve — the share of live traffic on each version per day — is reconstructed from analytics here. For A/B work this is what you actually want: not the planned %, but the share of the experiment population that was running each build.

> ⚠️ **This is a dated SNAPSHOT.** Numbers below were computed **2026-06-29** over the window **2026-04-24 → 2026-06-28** (06-29 omitted — T-1 export lag means the latest full day is 06-28). They go stale. The query at the bottom is the source of truth — re-run it to refresh. (Per the timeline doc's philosophy: trust the query, not cached numbers.)

> **🔑 FUNNEL BOUNDARY — the iOS ATT analytics fix (2026-06-23).** `2606.23.0` (cut 06-23) is the **first build with the iOS ATT analytics fix** (keeps first-party analytics on when ATT is denied; commit `31a676db`). Before it, iOS ATT-deniers were invisible in GA4 → all iOS funnel/onboarding/paywall metrics were biased toward the ~17% who allow tracking. **iOS analytics are only trustworthy from ~2026-06-23 onward**, ramping to full as `2606.23.0`/`2606.26.0` reach 100%. Confirmed recovering: iOS back-half onboarding completion went 16–18% (pre-fix builds) → ~79% (fixed builds), matching Android. **Treat 06-23 as a hard cohort cut for any iOS or pooled A/B read — do not pool pre- and post-06-23 iOS data.**

---

## The headline for A/B analysis

**iOS and Android are NOT on the same version at the same calendar date.** A date-only cohort mixes two different paywall/funnel builds.

- **iOS ramps fast** — a release crosses 50% of iOS DAU in **~2–3 days** (App Store phased release + fast iOS update behaviour).
- **Android ramps slow** — **~6+ days** to 50%, and a Play *staged rollout* can hold a build at a low % for weeks.
- **Net effect right now (snapshot 2026-06-28):**
  - **Android**: 66% on `2606.26.0`, with `2606.23.0` (18%) and `2606.17.0` (9%) trailing.
  - **iOS**: 65% on `2606.26.0`, with `2606.23.0` (28%) trailing; `2606.11.0` down to 3%.

  → Both platforms have now converged onto the **same** newest build (`2606.26.0`, ~65% each) — a brief alignment after weeks of divergence. But the second-place builds differ (Android still has 9% on `2606.17.0`; iOS's tail is `2606.23.0`), and the convergence is recent, so still split A/B cohorts by `platform` **and** `app_info.version`, never by calendar date alone.

**⚠️ Versions newer than the timeline doc exist.** The timeline doc currently stops at `26.5.19` (+ an unreleased note). BigQuery shows **`2605.21.0`**, **`2606.5.0`**, **`2606.11.0`**, **`2606.17.0`**, **`2606.23.0`** and **`2606.26.0`** already carrying (or dominating) traffic. The version scheme also switched from `26.5.x` → `YYMM.build.patch` (`2605.x`, `2606.x`). The currently-dominant build — **`2606.26.0`** (~65% on both platforms) — plus the ATT-fix build **`2606.23.0`** are **not documented in the timeline doc**. **The timeline doc needs a catch-up entry for these** — their paywall/analytics deltas (notably the ATT fix in `2606.23.0`) aren't documented yet.

**⚠️ 2026-06-08 Android is a data anomaly — do not use it.** Android DAU that day = **84,559** vs a ~14.8k daily median (iOS normal). Almost certainly a backfill / bot / duplicate-processing artefact in that daily table. Current-share figures below are computed on **2026-06-28** (a clean day — Android 13,323 / iOS 3,508 DAU). Exclude 2026-06-08 Android from any analysis until explained.

---

## Modern releases — arrival & rollout speed

`hit 10%` / `hit 50%` = first day the version reached that share of its platform's DAU. `—` = never reached it within the window (still ramping or held on staged rollout). `share 06-28` = share of platform DAU on the last clean day (CUR).

### Android

| Version     | First seen | hit 10%    | hit 50%    | Peak share (day)   | share 06-28 |
| ----------- | ---------- | ---------- | ---------- | ------------------ | ----------- |
| `26.4.28`   | 2026-04-27 | 2026-04-27 | 2026-04-27 | 100% (04-27)       | 0.6%        |
| `26.5.9`    | 2026-05-06 | 2026-05-09 | 2026-05-10 | 67% (05-11)        | 0.2%        |
| `26.5.10`   | 2026-05-08 | 2026-05-12 | 2026-05-13 | 72% (05-13)        | 0.2%        |
| `26.5.13`   | 2026-05-10 | 2026-05-14 | 2026-05-15 | 92% (05-20)        | 0.8%        |
| `26.5.19`   | 2026-05-18 | 2026-05-23 | 2026-05-24 | 94% (06-02)        | 3.3%        |
| `2605.21.0` | 2026-05-22 | 2026-06-05 | 2026-06-12 | 82% (06-15)        | 2.2%        |
| `2606.11.0` | 2026-06-11 | 2026-06-16 | 2026-06-17 | 57% (06-17)        | 0.6%        |
| `2606.17.0` | 2026-06-14 | 2026-06-18 | 2026-06-19 | 85% (06-22)        | 8.6%        |
| `2606.23.0` ⭐ | 2026-06-21 | 2026-06-24 | 2026-06-25 | 65% (06-26)        | 17.8%       |
| `2606.26.0` | 2026-06-23 | 2026-06-27 | 2026-06-28 | 66% (06-28)        | **65.7%**   |

⭐ = first build with the iOS ATT analytics fix (matters for iOS; Android was never affected, listed here for the rollout record). Android takes ~6 days to 50% (`26.5.19`: first 05-18 → 50% on 05-24). `2605.21.0` was a slow/held Play staged rollout — first seen 05-22 but didn't cross 50% until 06-12 — then superseded by `2606.11.0` → `2606.17.0` → `2606.23.0` → `2606.26.0`, which is now dominant at 66%.

### iOS

| Version     | First seen | hit 10%    | hit 50%    | Peak share (day)   | share 06-28 |
| ----------- | ---------- | ---------- | ---------- | ------------------ | ----------- |
| `26.4.28`   | 2026-04-28 | 2026-04-28 | 2026-04-28 | 100% (04-29)       | 0.0%        |
| `26.5.9`    | 2026-05-06 | 2026-05-10 | 2026-05-12 | 72% (05-12)        | 0.1%        |
| `26.5.10`   | 2026-05-10 | 2026-05-12 | 2026-05-14 | 57% (05-14)        | 0.0%        |
| `26.5.13`   | 2026-05-13 | 2026-05-14 | 2026-05-15 | 95% (05-18)        | 0.3%        |
| `26.5.19`   | 2026-05-18 | 2026-05-19 | 2026-05-20 | 98% (06-02)        | 0.7%        |
| `2605.21.0` | 2026-05-26 | 2026-06-03 | 2026-06-05 | 93% (06-07)        | 0.4%        |
| `2606.5.0`  | 2026-06-05 | 2026-06-08 | 2026-06-10 | 96% (06-16)        | 1.5%        |
| `2606.11.0` | 2026-06-11 | 2026-06-18 | 2026-06-19 | 94% (06-23)        | 3.3%        |
| `2606.23.0` ⭐ | 2026-06-23 | 2026-06-24 | 2026-06-25 | 86% (06-26)        | 28.3%       |
| `2606.26.0` | 2026-06-26 | 2026-06-27 | 2026-06-28 | 65% (06-28)        | **65.3%**   |

⭐ = first build with the iOS ATT analytics fix (commit `31a676db`) — see the funnel-boundary callout up top. iOS takes ~2–3 days to 50% (`26.5.19`: first 05-18 → 50% on 05-20). The June cadence was rapid: `2606.5.0` → `2606.11.0` → `2606.23.0` → `2606.26.0`, each displacing the last within ~1 week; `2606.26.0` is at 65% by 06-28 and still climbing.

---

## Weekly dominant version (calendar → version map)

Quickest way to pick a clean A/B window: find the week, read off which build the platform was actually running. Top-3 share of platform DAU, weeks Monday-anchored.

### Android

| Week of    | #1                | #2                 | #3            |
| ---------- | ----------------- | ------------------ | ------------- |
| 2026-04-13 | `3.6.15` 57%      | `3.6.13` 27%       | `3.5.76` 6%   |
| 2026-04-20 | `3.6.17` 35%      | `3.6.20` 26%       | `3.6.15` 26%  |
| 2026-04-27 | `3.6.20` 61%      | `26.4.28` 24%      | `3.6.15` 3%   |
| 2026-05-04 | `26.4.28` 72%     | `26.5.9` 11%       | `3.6.20` 5%   |
| 2026-05-11 | `26.5.13` 32%     | `26.5.10` 30%      | `26.5.9` 18%  |
| 2026-05-18 | `26.5.13` 70%     | `26.5.19` 15%      | `26.4.28` 3%  |
| 2026-05-25 | `26.5.19` 81%     | `26.5.13` 7%       | `26.4.28` 2%  |
| 2026-06-01 | `26.5.19` 83%     | `2605.21.0` 5%     | `26.5.13` 2%  |
| 2026-06-08 | `26.5.19` 60%     | `2605.21.0` 28%    | `26.5.13` 1%  _(incl. 06-08 anomaly)_ |
| 2026-06-15 | `2606.17.0` 34%   | `2605.21.0` 29%    | `2606.11.0` 21% |
| 2026-06-22 | `2606.17.0` 43%   | `2606.23.0` 29%    | `2606.26.0` 14% |

### iOS

| Week of    | #1                | #2                 | #3            |
| ---------- | ----------------- | ------------------ | ------------- |
| 2026-04-13 | `3.6.15` 50%      | `3.6.9` 32%        | `3.6.17` 10%  |
| 2026-04-20 | `3.6.17` 69%      | `3.6.21` 21%       | `3.6.15` 3%   |
| 2026-04-27 | `26.4.28` 46%     | `3.6.21` 45%       | `3.6.17` 2%   |
| 2026-05-04 | `26.4.28` 90%     | `26.5.9` 2%        | `3.6.21` 2%   |
| 2026-05-11 | `26.5.13` 32%     | `26.5.9` 27%       | `26.5.10` 22% |
| 2026-05-18 | `26.5.19` 54%     | `26.5.13` 37%      | `26.4.28` 1%  |
| 2026-05-25 | `26.5.19` 92%     | `26.5.13` 2%       | `26.4.28` 1%  |
| 2026-06-01 | `26.5.19` 53%     | `2605.21.0` 41%    | `26.5.13` 1%  |
| 2026-06-08 | `2606.5.0` 68%    | `2605.21.0` 24%    | `26.5.19` 3%  |
| 2026-06-15 | `2606.5.0` 54%    | `2606.11.0` 39%    | `26.5.19` 1% |
| 2026-06-22 | `2606.11.0` 43%   | `2606.23.0` 36%    | `2606.26.0` 13% |

> Read the divergence: week of 06-01, Android is 83% `26.5.19` while iOS is split `26.5.19` 53% / `2605.21.0` 41% — mid-transition on iOS, not yet on Android. Same calendar week, different code mix per platform. By the week of 06-22 both platforms are mid-churn through `2606.23.0`→`2606.26.0` (the post-ATT-fix builds), so the **whole 06-22 week straddles the 06-23 analytics boundary** — split it by version, don't read it as one cohort.

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
WHERE _TABLE_SUFFIX BETWEEN '20260424' AND '20260628'
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
  WHERE _TABLE_SUFFIX BETWEEN '20260424' AND '20260628'
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
