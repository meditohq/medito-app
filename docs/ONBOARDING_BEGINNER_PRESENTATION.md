# Beginner first-meditation presentation

Prepared 2026-09-22; not released or independently A/B tested.

The inline first-meditation card adds the existing localized session title and
a full-width, labeled Start / Pause / Play button for `never_tried` and `a_little`.
Audio, duration copy, skip behavior, completion reveal and event names stay fixed.
`regular_practice` keeps the existing presentation in both experienced-meditation
arms. Keep subsequent changes behind the same audience gate while that test runs.

## Interaction with other experiments

- `onboarding_experienced_meditation`: do not change its shared UI unconditionally.
  The beginner-only gate preserves the offered treatment and control presentation.
- `higher_floor_2`: in this checkout the donation ask precedes this screen, so the
  initial offer is unaffected. Later engagement, gifts and donor retention may
  change. Record the first shipped version and rollout dates by platform; inspect
  pricing effects by release cohort rather than assuming no downstream interaction.
- Reminder picker: assignment and picker UI are unaffected, but downstream
  onboarding completion and engagement can change with the new result screen.
- Queued donation timing: this checkout still has the fixed early ask, despite
  the timing spec documenting implementation elsewhere. Freeze the meditation UI
  before launching timing, and use that same UI in both timing arms. Changing it
  during enrollment would introduce another version of the experience, especially
  for the arm that asks after meditation.

This is a usability change, not evidence of increased activation or retention.
Decision 2026-09-22: ship without a separate A/B test and monitor before/after.
Compare unique beginner users who start / shown, complete / shown, and complete /
start, with equal follow-up windows and separate platform/app-version cohorts.
Existing shown/begin/skip and audio completion events can monitor the rollout,
segmented by experience, app version and platform. A before/after comparison is
not a causal readout. A later beginner-specific randomized test can evaluate more
substantial changes to copy, voice or audio separately from donation timing.
