# Historical local prototype — superseded

Not the current delivery plan. Server campaigns replace local scheduling.

# Supporter appeal v1

Status: local implementation, not released or sent. The app and checkout website
changes must both ship before the fallback path can be counted end to end. No
new server targeting, warehouse queries, cloud schedules or payment configuration.
Publish the checkout metadata support before releasing the app experiment.

The appeal Donate CTA now opens a dedicated native donation screen reusing
`NativeDonationPage`, with an immediate top-right Close button in the header
and no second close button in the donation content. It fetches `/paywall` with
`source=announcement` and the existing user/currency/country. Localized prices,
suggested amounts, available frequencies and the server's pricing experiment
ID/variant are preserved. Yearly is supported when that assigned configuration
offers it; this change does not enable yearly or one-time in server settings.
Failures/empty configuration show Retry rather than inventing prices. The
onboarding native/webview choice and end-screen test are unchanged. This
announcement source deliberately renders natively; its `paywall_id` records that
renderer separately from the server ladder assignment.

This remains the original local A/B/C prototype described below. The later
server-controlled targeting and supportive-versus-fundraising copy comparison
are proposals, not implemented or launched by this change.

## Copy

Verified in Firebase Messaging on 20 October 2026, completed campaign dated
8 June 2026 at 19:52:54: https://console.firebase.google.com/project/medito-9165c/messaging

Title: **🫶 Your practice misses you 🫶**

Body: **Just a few minutes of stillness can change your whole day. Ready to breathe?**

Announcement (adapted from medito-api commit 95c15f90):

> We need your help to keep Medito free for everyone.
>
> Medito is a nonprofit; no ads, no paywalls. If it's been part of your life,
> a small monthly or yearly donation helps keep this space open for all.

CTA: Donate now. Dismiss suppresses this campaign permanently on that install
and records `appeal_dismissed`. There is no support-status button or reason dialog.
Dismissal is not evidence of a person's willingness to donate. No historical shortfall is asserted as current.
Copy is English, matching the original campaign.

## Experiment and audience

Sticky equal random assignment per install: A usual app; B local announcement;
C same announcement plus one extra local notification tomorrow at 18:00 device
local time (18:30 when a daily reminder uses the 18:00 hour). Existing reminders
and donation entry points remain. A server donation announcement is replaced
by the local appeal in B/C to avoid double asks; other server announcements
remain visible. A retains the usual server announcement, including any existing
fundraising announcement. Thus the contrast is the new flow versus usual app,
not necessarily fundraising versus no fundraising at all.

Eligibility requires at least three recorded completions, the first at least
30 days old, and the latest within 30 days. This is observed practice tenure,
not a claim about the original install date. No consistency-score threshold;
save its pre-assignment band for subgroup analysis. Exclude locally known
donors, existing snoozes and campaign dismissals. Local records cannot identify
donations made elsewhere or prevent cross-device/reinstall re-enrollment.

Record notification availability before assignment in every arm. C schedules
only with an existing enabled reminder preference and granted OS permission;
there is no new permission prompt. Keep all assigned installs in intent-to-treat
results, and also compare the pre-assignment notification-enabled stratum across
all three arms. Do not drop C non-openers, denied notifications or failed sends.

Card expires seven days after assignment. Never re-enroll or auto-repeat this
campaign; monthly versus quarterly cadence is a separate future test. New
donation, dismissal or disabling reminders cancels the pending extra notification.
Build with `--dart-define=SUPPORTER_APPEAL_ENABLED=false` to stop new enrollment
and cards in a subsequent release; OS notifications already scheduled need an
app launch to cancel. No server-side kill switch is claimed.

## Measurement

Campaign: `support_medito_june_copy_v1`; arm key: `supporter_appeal_v1`.
Random 128-bit `appeal_id` identifies the install assignment, with no personal
information in the identifier. The one notification uses that ID as its click
join key. Warm/background and terminated-launch paths use the same validation
and persist one unique open. Opening a different reminder never creates this
campaign's click record. The notification opens normal Home, not checkout.

Events (existing analytics consent applies):

- `appeal_assigned`: denominator, including A and people who never tap.
- `appeal_notification_scheduled`: scheduling acknowledgement, NOT delivery.
- `appeal_notification_opened`: unique actual tap with its click ID and time.
- `appeal_announcement_viewed`: first visible paint, not hidden Home build.
- `appeal_donate_tapped`, `appeal_dismissed`.
- Existing successful donation events also carry assignment and recent tap tags.

Native payments and web fallback carry the arm, assignment ID/time, baseline
consistency band and notification eligibility. An actual notification tap adds
`appeal_notification_click_id` and `appeal_notification_tapped_at` for seven
days; membership in C alone does not claim a tap. Assignment tags persist for
90 days for retention follow-up. These are associations, not causal credit.

The appeal CTA additionally sends scoped UTMs: source `medito_app`, medium
`in_app_announcement`, campaign above, content B/C. It never writes over stored
acquisition UTMs; the CTA payment also preserves their values in separate
`acquisition_utm_*` metadata. Other payment entry points keep their acquisition UTMs and
still carry assignment/recent-tap tags. Existing server pricing experiment
metadata remains separate. No donor contact details are added to campaign URLs.

Use the actual paid Stripe charge/initial invoice as payment truth; a Donate
tap or abandoned PaymentIntent is not a donation. Compare distinct paid donors
per all assigned eligible installs within seven days, cash by original currency
within 28 days, and successful renewals at matched 30/60/90-day maturity. Analyze
the notification-click-to-paid funnel separately using the shared click ID and
requiring paid time after tapped time within seven days. Count unique click IDs,
deduplicate payments/invoices, exclude failed/zero-paid checkouts, and retain
refunds. Do not treat annual subscription status as a successful annual renewal.

Notification scheduling does not supply a delivery denominator. Permission
revocations, dismissals and continued app use are useful guardrails; absent
return events do not prove uninstall. Analytics opt-outs and cross-device
identity limit completeness. Do not manufacture exposure records for opt-outs.

### Reminder timing (observational, no sending-time change)

Existing onboarding, Settings and end-screen reminder-selection events already
record the chosen hour/minute. New daily-series and appeal payloads also carry:

- `notification_instance_id`: unique for each scheduling instance, even when
  the OS notification ID is reused after a session.
- `scheduled_at`: UTC epoch seconds; `scheduled_local_hour`,
  `scheduled_local_minute`, `scheduled_utc_offset_min`, `scheduled_timezone`
  describe the device clock at that planned instant. The timezone name may be
  an abbreviation, not an IANA identifier; retain the offset and instant.
- Appeal scheduling snapshots `reminder_hour`/`reminder_minute` and, where known,
  `nearest_reminder_gap_min`: signed distance from the appeal to the nearest
  **pending** daily reminder (-30 means the daily reminder precedes it by 30
  minutes). Legacy requests without a planned-time payload leave this unknown.

`notification_scheduled` is recorded per successful OS scheduling call, not per
attempt and not as delivery. Pending tagged requests produce
`notification_cancelled` after a successful explicit cancellation. Replacements
get new instance IDs. `notification_opened` carries the same planned snapshot,
the opened local hour/minute/offset and `seconds_since_scheduled` when valid.
The unique campaign-open event carries this context too. Analytics consent
still applies; analytics failure does not fail scheduling/cancellation.

The gap is a snapshot at appeal scheduling: later reminder changes can make it
stale. Join scheduling/cancellation events by instance ID and event timestamps
to reconstruct the intended schedule at open time. Do not interpret missing
cancellation events as proof of delivery: OS removals, app upgrades, permission
revocation, analytics gaps and old payloads are not fully observable. Deduplicate
generic opens by instance ID before computing scheduled-to-open rates. These
are not delivered-to-open rates. Android inexact scheduling can delay delivery,
so a planned gap is not a measured delivery gap and open-minus-planned time is
not delivery latency. Timing is not randomized; use correlations to choose a
later controlled test, not as evidence that a particular time causes donations.

## Verification and launch

### Try the UI in development

Real-backend dev builds use the same eligibility, sticky assignment and expiry
rules as other builds. A fresh install will not immediately show the appeal;
the normal full-app mock mode skips automatic appeal enrollment altogether.

For an immediate UI walkthrough, select **Supporter appeal preview · 🍎** in
VS Code, or run on a simulator:

```sh
flutter run -t lib/main_supporter_appeal_preview.dart --dart-define=MOCK_MODE=true -d <simulator-id>
```

The separate entrypoint requires debug + mock mode and never replaces the
normal app startup. It uses the actual announcement card and donation screen,
in-memory preferences, a sample B assignment and sample EUR monthly/yearly
ladders. These sample prices are not a read of the active server experiment.
Tap Donate now, change frequency/amount, and tap Donate to see a simulated
checkout acknowledgement. No payment controller, payment API or Stripe sheet
is invoked. Reset preview restores the card after Dismiss. The notification
copy is a visual preview only; this entrypoint schedules no notifications and
does not verify actual push/local delivery, live attribution or server pricing.
Use a separate simulator so installing the app does not replace an existing
dev installation or its real local data. Native SDK startup still follows the
host's iOS configuration; Dart mock mode skips custom analytics. The prepared
simulator copy additionally disables native automatic analytics via its built
Info.plist, without changing the app's source configuration.

### Checks

- Flutter eligibility, assignment, expiry, tap deduplication and OS scheduling
  tests use mocked channels; they send no real notification or charge.
- Native payment-request tests capture all three donation frequencies.
- Announcement native-screen tests check the actual monthly/yearly UI dispatch,
  source-specific localized amounts, unchanged server experiment attribution,
  campaign metadata, and hiding yearly when the server does not offer it.
- Timing tests cover unique scheduling IDs, UTC/local offsets, signed pending
  reminder gaps, missing/legacy payloads and the unchanged appeal schedule.
- Card widget test checks hidden/visible Home and dismissal.
- Checkout `node --test test/supporter-appeal-attribution.test.mjs` executes the
  real inline parser/request builder with fake checkout inputs and no Stripe call.
- Before production readout, verify a device tap from both terminated and
  background states, then a **test-mode** donation through native and fallback
  checkout. Confirm the actual Stripe metadata and analytics records. No real
  donation, live API write, build upload or deployment was performed here.
