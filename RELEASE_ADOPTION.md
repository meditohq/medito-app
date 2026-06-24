# Release Adoption — version rollout curves (iOS vs Android)

**Companion to [`PAYWALL_ANALYTICS_TIMELINE.md`](./PAYWALL_ANALYTICS_TIMELINE.md).** That file says _when a version was cut_. This file says **when each version actually reached users, how fast it ramped, and the iOS↔Android skew** — derived empirically from BigQuery `app_info.version`, not from store-console rollout settings.

> **Why this exists:** the deploy pipeline ships to the Play **production** track and the App Store with **no rollout fraction in code** ([`release.yml`](./.github/workflows/release.yml)). The staged-rollout % lives only in Play Console / App Store Connect and is not version-controlled. So the *real* rollout curve — the share of live traffic on each version per day — is reconstructed from analytics here. For A/B work this is what you actually want: not the planned %, but the share of the experiment population that was running each build.

> ⚠️ **This is a dated SNAPSHOT.** Numbers below were computed **2026-06-22** over the window **2026-04-15 → 2026-06-22**. They go stale. The query at the bottom is the source of truth — re-run it to refresh. (Per the timeline doc's philosophy: trust the query, not cached numbers.)

---

## The headline for A/B analysis

**iOS and Android are NOT on the same version at the same calendar date.** A date-only cohort mixes two different paywall/funnel builds.

- **iOS ramps fast** — a release crosses 50% of iOS DAU in **~2–3 days** (App Store phased release + fast iOS update behaviour).
- **Android ramps slow** — **~6+ days** to 50%, and a Play *staged rollout* can hold a build at a low % for weeks.
- **Net effect right now (snapshot 2026-06-22):**
  - **Android**: 82% on `2606.17.0`, with stragglers on `26.5.19` (4.5%) and `2605.21.0` (3.9%).
  - **iOS**: 90% on `2606.11.0`, with `2606.5.0` (4.0%) trailing.

  → iOS and Android have each fully turned over to their newest build by 06-22 (`2606.11.0` on iOS, `2606.17.0` on Android — **different patch builds**). For any window earlier in June the platforms were mid-transition on different versions, so always split A/B cohorts by `platform` **and** `app_info.version`, never by calendar date alone.

**⚠️ Versions newer than the timeline doc exist.** The timeline doc currently stops at `26.5.19` (+ an unreleased note). BigQuery shows **`2605.21.0`**, **`2606.5.0`**, **`2606.11.0`** and **`2606.17.0`** already carrying (or dominating) traffic. The version scheme also switched from `26.5.x` → `YYMM.build.patch` (`2605.x`, `2606.x`). The currently-dominant builds — **`2606.11.0`** (iOS, ~90%) and **`2606.17.0`** (Android, ~82%) — are **not documented in the timeline doc**. **The timeline doc needs a catch-up entry for these** — their paywall/analytics deltas aren't documented yet.

**⚠️ 2026-06-08 Android is a data anomaly — do not use it.** Android DAU that day = **92,577** vs a ~17k daily median (iOS normal at 4,260). Almost certainly a backfill / bot / duplicate-processing artefact in that daily table. Current-share figures below are computed on **2026-06-22** (a clean day — Android 16,007 / iOS 3,782 DAU). Exclude 2026-06-08 Android from any analysis until explained.

---

## Modern releases — arrival & rollout speed

`hit 10%` / `hit 50%` = first day the version reached that share of its platform's DAU. `—` = never reached it within the window (still ramping or held on staged rollout). `share 06-22` = share of platform DAU on the last clean day (CUR).

### Android

| Version     | First seen | hit 10%    | hit 50%    | Peak share (day)   | share 06-22 |
| ----------- | ---------- | ---------- | ---------- | ------------------ | ----------- |
| `26.4.28`   | 2026-04-27 | 2026-05-01 | 2026-05-02 | 83% (05-06)        | 0.5%        |
| `26.5.9`    | 2026-05-06 | 2026-05-09 | 2026-05-10 | 59% (05-11)        | 0.2%        |
| `26.5.10`   | 2026-05-08 | 2026-05-12 | 2026-05-13 | 64% (05-13)        | 0.2%        |
| `26.5.13`   | 2026-05-10 | 2026-05-14 | 2026-05-15 | 83% (05-19)        | 0.8%        |
| `26.5.19`   | 2026-05-18 | 2026-05-23 | 2026-05-24 | 87% (06-02)        | 4.5%        |
| `2605.21.0` | 2026-05-22 | 2026-06-06 | 2026-06-12 | 77% (06-15)        | 3.9%        |
| `2606.11.0` | 2026-06-11 | 2026-06-16 | 2026-06-17 | 53% (06-17)        | 1.8%        |
| `2606.17.0` | 2026-06-14 | 2026-06-18 | 2026-06-19 | 82% (06-22)        | **82.1%**   |

Android takes ~6 days to 50% (`26.5.19`: first 05-18 → 50% on 05-24). `2605.21.0` was a slow/held Play staged rollout — first seen 05-22 but didn't cross 50% until 06-12 — before being superseded within days by `2606.11.0` then `2606.17.0`, which is now dominant at 82%.

### iOS

| Version     | First seen | hit 10%    | hit 50%    | Peak share (day)   | share 06-22 |
| ----------- | ---------- | ---------- | ---------- | ------------------ | ----------- |
| `26.4.28`   | 2026-04-28 | 2026-04-29 | 2026-04-30 | 92% (05-08)        | 0.3%        |
| `26.5.9`    | 2026-05-06 | 2026-05-10 | 2026-05-12 | 68% (05-12)        | 0.1%        |
| `26.5.10`   | 2026-05-10 | 2026-05-12 | 2026-05-14 | 53% (05-14)        | 0.1%        |
| `26.5.13`   | 2026-05-13 | 2026-05-14 | 2026-05-15 | 90% (05-18)        | 0.3%        |
| `26.5.19`   | 2026-05-18 | 2026-05-19 | 2026-05-21 | 93% (06-01)        | 1.1%        |
| `2605.21.0` | 2026-05-26 | 2026-06-03 | 2026-06-05 | 88% (06-07)        | 0.7%        |
| `2606.5.0`  | 2026-06-05 | 2026-06-08 | 2026-06-10 | 92% (06-16)        | 4.0%        |
| `2606.11.0` | 2026-06-11 | 2026-06-18 | 2026-06-19 | 90% (06-22)        | **89.7%**   |

iOS takes ~2–3 days to 50% (`26.5.19`: first 05-18 → 50% on 05-21). `2606.5.0` and `2606.11.0` shipped a week apart, so `2606.5.0` peaked at 92% on 06-16 then was rapidly displaced by `2606.11.0` (90% by 06-22).

---

## Weekly dominant version (calendar → version map)

Quickest way to pick a clean A/B window: find the week, read off which build the platform was actually running. Top-3 share of platform DAU, weeks Monday-anchored.

### Android

| Week of    | #1                | #2                 | #3            |
| ---------- | ----------------- | ------------------ | ------------- |
| 2026-04-13 | `3.6.15` 73%      | `3.6.13` 11%       | `3.5.76` 6%   |
| 2026-04-20 | `3.6.17` 35%      | `3.6.20` 26%       | `3.6.15` 26%  |
| 2026-04-27 | `3.6.20` 61%      | `26.4.28` 24%      | `3.6.15` 3%   |
| 2026-05-04 | `26.4.28` 72%     | `26.5.9` 11%       | `3.6.20` 5%   |
| 2026-05-11 | `26.5.13` 32%     | `26.5.10` 30%      | `26.5.9` 18%  |
| 2026-05-18 | `26.5.13` 70%     | `26.5.19` 15%      | `26.4.28` 3%  |
| 2026-05-25 | `26.5.19` 81%     | `26.5.13` 7%       | `26.4.28` 2%  |
| 2026-06-01 | `26.5.19` 83%     | `2605.21.0` 5%     | `26.5.13` 2%  |
| 2026-06-08 | `26.5.19` 60%     | `2605.21.0` 28%    | `26.5.13` 1%  _(incl. 06-08 anomaly)_ |
| 2026-06-15 | `2606.17.0` 34%   | `2605.21.0` 29%    | `2606.11.0` 21% |
| 2026-06-22 | `2606.17.0` 82%   | `26.5.19` 4%       | `2605.21.0` 4% |

### iOS

| Week of    | #1                | #2                 | #3            |
| ---------- | ----------------- | ------------------ | ------------- |
| 2026-04-13 | `3.6.15` 67%      | `3.6.17` 15%       | `3.6.9` 11%   |
| 2026-04-20 | `3.6.17` 69%      | `3.6.21` 21%       | `3.6.15` 3%   |
| 2026-04-27 | `26.4.28` 46%     | `3.6.21` 45%       | `3.6.17` 2%   |
| 2026-05-04 | `26.4.28` 90%     | `26.5.9` 2%        | `3.6.21` 2%   |
| 2026-05-11 | `26.5.13` 32%     | `26.5.9` 27%       | `26.5.10` 22% |
| 2026-05-18 | `26.5.19` 54%     | `26.5.13` 37%      | `26.4.28` 1%  |
| 2026-05-25 | `26.5.19` 92%     | `26.5.13` 2%       | `26.4.28` 1%  |
| 2026-06-01 | `26.5.19` 53%     | `2605.21.0` 41%    | `26.5.13` 1%  |
| 2026-06-08 | `2606.5.0` 68%    | `2605.21.0` 24%    | `26.5.19` 3%  |
| 2026-06-15 | `2606.5.0` 54%    | `2606.11.0` 39%    | `26.5.19` 1% |
| 2026-06-22 | `2606.11.0` 90%   | `2606.5.0` 4%      | `26.5.19` 1% |

> Read the divergence: week of 06-01, Android is 83% `26.5.19` while iOS is split `26.5.19` 53% / `2605.21.0` 41% — mid-transition on iOS, not yet on Android. Same calendar week, different code mix per platform.

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
WHERE _TABLE_SUFFIX BETWEEN '20260415' AND '20260608'
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
  WHERE _TABLE_SUFFIX BETWEEN '20260415' AND '20260622'
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
