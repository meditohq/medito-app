# Supporter appeal — current server integration

Status: local implementation/PR, not released. No live campaign has been sent.

This app now registers preferences with the app backend and reads its sticky
campaign assignment. Campaign pushes are sent only by the server. The former
local scheduling method has been removed; its old pending notification ID is
cancelled on migration. The preview entrypoint still uses sample in-memory data
and simulated checkout.

See [the companion backend PR](https://github.com/meditohq/medito-api/pull/16)
and its `docs/supporter-campaigns.md` for the shared API contract, campaign
lifecycle, delivery guarantees and release/setup steps.

The app backend owns campaign definitions, sticky assignments and FCM HTTP v1
sending. The donation API continues to own prices, currencies, frequency options
and payment-ladder assignments; no Stripe integration or donation settings change.
The app renders the server announcement and prefers its native donation page.
If native rendering is disabled, configuration is missing/invalid, SDK setup or
payment methods are unavailable, or setup takes more than eight seconds, the
same screen switches to the web donation page with an immediate Close button.
The web page still uses the native payment sheet when SDK setup and payment
methods are available (`isInAppPaymentAvailable=true`). Only an unavailable native
payment integration uses Stripe.js browser checkout instead. A native sheet
initialization/availability failure forces browser checkout; cancellation, card
declines and ambiguous payment errors do not trigger another checkout.
Campaign/source/account metadata is preserved. Bank redirects return to the
checkout and retrieve Stripe's actual status; only succeeded payments mark the
install as a donor. Processing payments remain pending. Publish the companion
website changes before testing this path.

Android campaign notifications use the existing `medito_supporter_appeal`
channel (Support Medito), including foreground presentation. Creating it adds no
new permission prompt; OS channel settings still control its visibility.

The admin is `/admin/campaigns` on `paywall.meditofoundation.org` (production) or
`test.meditofoundation.org` (preview app API). It supports drafts, audience/copy
editing, scheduling, bounded audience previews, FCM validation-only, activation,
pause and permanent completion. Definitions freeze after first activation.
Only one campaign may be active. There is no automatic monthly recurrence.

Default UI proposal: A 20% usual app (no new push/card), B 40% supportive push,
C 40% fundraising push, with the same announcement and checkout for B/C. Existing
app asks remain in all groups. Thus A is usual app, not a guaranteed absence of
all fundraising. Actual weights/copy are saved explicitly in a draft.

## Audience and identity

Only clients that registered through the new authenticated sync endpoint enter
the pool. Existing `profiles.fcmt` alone never enrolls an old app version.
The server summarizes the stored, validated `stats.audio_completed`: distinct
id/timestamp completions, first practice >=30 days ago, >=3 completions, practice
and preference sync within <=30 days. Account/server creation is not install age.
No consistency-score cutoff. A band captured before assignment is stored for
subgroup reporting; unknown stays unknown.

All eligible users, including notification-denied users, are randomized once.
Notification eligibility is saved at assignment; denied users remain in their
assigned group and can see the B/C card. New push attempts require granted OS
notification permission, a token and no donor/snooze/dismissal suppression.
Daily reminders can be off; their saved time is optional observational metadata
and never a campaign eligibility gate. There is no separate supporter toggle or
permission prompt. Authenticated server signout disables campaign pushes for the
departing account until it next syncs its notification permission. Offline
signout cannot reach the sender or recall already accepted pushes. Preferences
sync at Home/resume, donation/snooze and reminder changes. Dismissal retries
through ordinary sync.

Known local donations and the legacy `has_active_subscription` profile flag
suppress; positive donor suppression is sticky. This is **not a complete donor
identity feed**: an unlinked website gift or a donation made on another identity
may be missed. Validate linked donor coverage before a broad campaign; the
prototype does not claim all historical/external supporters are identified.
Cached assignments and queued notification opens are scoped to their authenticated
account. Sign-out/account deletion clears them, and responses from an earlier
account cannot restore attribution after an identity change. Older unowned caches
require an authenticated refresh before use.

Reinstalls without a shared identity can still re-enroll. A token hash avoids
duplicate campaign allocation/cooldowns for multiple identities sharing a device.

Eligibility and token data are operational first-party records. The server never
receives the app's raw local history in registration; it uses its existing stats.
FCM payloads contain opaque assignment/campaign IDs, no email or user ID. Account
deletion cascades to subscribers and assignments. Reporting is aggregate only.

## Delivery guarantees and limits

Minute cron: enroll <=100 users per run up to the campaign participant cap,
then attempt <=50 queued B/C sends. This is a rollout over time, not a single
instant simultaneous blast. The campaign window is at most seven days; a later
campaign respects a global >=30-day assignment cooldown (including controls).
UTC campaign windows are configured from the admin's local-time inputs. Within
that window, new push attempts run only from 09:00 to 21:00 using each device's
latest synced UTC offset. Quiet recipients remain pending and are filtered before
the 50-recipient batch limit; they cannot block daytime recipients. Provider TTL
is capped at the local closing time with a 15-second request margin, and new
claims stop 16 seconds before closing. Offset changes are rechecked at claim.
Offsets are snapshots: travel or daylight-saving changes after the latest sync
can make them stale until the next Home/resume/settings sync. This does not
randomize time of day or avoid collisions with daily reminders.

Each outbound call is preceded by an atomic D1 `pending -> sending` claim with
live campaign, recipient and dismissal checks. Captured token hashes must still
match. No automatic reclaim/re-send follows an uncertain response or a crash
after claim: these become `unknown`. Explicit provider errors become `failed`.
This is at-most-one **attempt**, not exactly-once delivery. FCM acceptance is not
delivery or an open; the API retains its message ID and sanitized error only.
Expired pending entries become suppressed. Bad unregistered tokens are cleared
only if they have not rotated in the meantime. Backlog timing can vary by arm;
retain assignment/send timestamps in any later analysis.

Pause stops new claims immediately on the next check. It cannot recall calls
already in flight or messages already accepted by FCM. Provider TTL is <=1 hour
and never extends past campaign end. APNs collapse IDs/Android tags reduce
presentation duplication; they are not a financial-grade idempotency guarantee.
Opens of previously accepted messages remain recordable during pause/completion
until their original expiry, even though the campaign card is no longer active.

The app sends analytics-consented unique opens/views; dismissal is an operational
preference. Generic notification opens carry the same push ID and planned UTC
time. Offline pending taps retry with the same ID and original app-recorded time.
The server separately stores receipt time. Only a matched owned assignment can
be attributed. The source click tags are associations, not causal proof.

## API

- Public `GET /supporter-campaigns/status`: `{version:3}`; no credentials.
- App JWT `POST /supporter-campaigns/sync`: push/supporter/snooze/reminder
  preferences (`push_allowed` reflects OS permission only) and consistency band; returns active assignment or null.
- App JWT `POST /supporter-campaigns/events`: owned `assignment_id`, kind
  `opened`, `viewed`, `dismissed`; duplicate events keep the first timestamp.
- Dedicated admin `GET/POST /admin/campaigns`; PATCH `/:id` includes the last
  revision. Editing stale revisions or frozen content is rejected.
- Admin GET `/:id/preview`: at most 100 eligible rows counted, no enrollment.
- Admin POST `/:id/validate`: own registered test user ID; FCM `validate_only`,
  no delivery, no experiment assignment. This does not test actual OS delivery.

No send/activate path accepts the app key. `CAMPAIGN_ADMIN_TOKEN` must be >=32
characters and different from `APP_KEY`. Keep it separate from the donation
API's mobile bearer token too. Allowed browser origins are the two admin hosts
and local development. Tokens stay in tab memory and do not enter public JS.

## Release order

1. Review/merge the companion backend PR. Apply `0015_supporter_campaigns.sql` using the
   existing users D1 migration process in each intended environment.
2. Set secret `CAMPAIGN_ADMIN_TOKEN` and secret `FCM_SERVICE_ACCOUNT` (JSON
   service-account identity with only the needed Firebase messaging permission
   in the correct Medito Firebase project). Do not paste either into chat, code
   or the app. Keep the sender flag false until validation is complete.
3. Deploy the app API to preview, then production through its existing release
   process. The website PR can deploy independently; it remains unavailable
   until this backend exists. Its production/preview hosts select different APIs.
4. Release the app PR to internal testers. Confirm registration, ownership,
   permission changes, donor/dismiss suppression, notification warm/cold opens,
   native monthly/yearly **test-mode** checkout and actual Stripe metadata.
   The existing in-memory simulator preview does not perform this live test.
5. Use the admin's validation-only action with the test user's registered ID.
   Then enable sending and activate a deliberately limited real-device pilot
   only after its audience/copy/window have been reviewed. No campaign is seeded
   active by a migration, deployment or admin draft save.

FCM messaging permissions/authentication and actual delivery need one real-device
test before calling the sender production-verified. Local tests substitute the
OAuth/FCM network and preserve SQL/pause/claim/cap behavior.

## App preview and checks

Run the isolated UI preview on a simulator with:

```sh
flutter run -t lib/main_supporter_appeal_preview.dart --dart-define=MOCK_MODE=true
```

It requires a debug build. Sample eligibility, prices and assignment are stored
in memory, and checkout shows a simulated result without calling a payment
controller or API. Use it to review announcement dismissal, the immediate
top-right Close button, monthly/yearly layout and reset behavior. It does not
exercise push delivery, backend registration or a real Stripe transaction.

Focused Flutter checks cover authenticated preference sync, offline tap retry
and opt-out, owned assignment attribution, native payment requests and existing
pricing-test metadata, actual card visibility, dismissal, reminder timing,
native screen frequency availability, email and amount regressions.

## Companion backend checks

`npm run test:campaigns` (Node 24+): real SQLite SQL/migration with a D1 adapter;
eligibility, admin isolation, draft gates, atomic caps, stable groups, cooldown,
ownership, account deletion, current suppression/pause, message envelope and a
full twice-run sender with fake OAuth/FCM including an ambiguous result.

`node --import tsx test/local-admin-demo.ts`: loopback-only UI fixture on 9989,
eight synthetic users, temporary in-memory DB, fixed clearly fake token, sender
disabled. Pair with the website dev server. It is not imported by the Worker.

The campaign admin requires backend status version 3, which uses OS notification
permission independently of daily reminders and retains local quiet hours. Only
migration 0015 is required. Deploy the reconciled website and this API release
before testing activation. Refresh an older admin page after deployment.
