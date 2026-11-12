// ignore_for_file: use_build_context_synchronously

import 'dart:async';

import 'package:medito/widgets/onboarding/onboarding_content.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:medito/constants/constants.dart';
import 'package:medito/constants/icons/medito_icons.dart';
import 'package:medito/constants/strings/analytics_event_constants.dart';
import 'package:medito/l10n/app_localizations.dart';
import 'package:medito/providers/notification/reminder_provider.dart';
import 'package:medito/providers/onboarding/onboarding_picker_mode_experiment.dart';
import 'package:medito/providers/settings/settings_providers.dart';
import 'package:medito/services/analytics/firebase_analytics_service.dart';
import 'package:medito/widgets/onboarding/onboarding_header_image.dart';
import 'package:medito/widgets/onboarding/onboarding_step_title.dart';
import 'package:medito/services/notifications/firebase_notifications_service.dart';
import 'package:medito/utils/notification_permission_flow.dart';
import 'package:medito/utils/permission_handler.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:medito/providers/shared_preference/shared_preference_provider.dart';
import 'package:medito/services/reminders/reminder_slots.dart';
import 'package:medito/services/reminders/daily_reminders_service.dart';
import 'package:medito/widgets/medito_icon.dart';

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({
    super.key,
    this.headerImage,
    this.onNext,
    this.intentIndex,
  });

  /// Hero image rendered at the top of the page, scrolling with the content.
  final String? headerImage;

  final VoidCallback? onNext;

  /// The index of the intent answer from the onboarding questionnaire.
  /// 0 = learn_properly, 1 = build_habit, 2 = stress_sleep_emotions.
  /// Null falls back to the generic copy.
  final int? intentIndex;

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen>
    with SingleTickerProviderStateMixin {
  bool _isProcessing = false;

  late final AnimationController _previewAnimation;

  /// Which time-of-day chip was picked; tagged on the reminder-set event as
  /// paramReminderSlot.
  String? _selectedSlot;

  /// Tagged on every event fired from this screen so analytics can
  /// distinguish the post-donation placement (re-introduced 26.6) from the
  /// pre-donation placement (removed 26.5.19). The time-chips A/B
  /// (onboarding_reminder_time_chips) concluded 2026-08-25 with chips shipped
  /// to everyone, so the experiment tags are gone.
  /// Sticky arm of the custom-picker entry-mode A/B
  /// (onboarding_reminder_picker_mode). Resolved in [initState] so every event
  /// from this screen carries it.
  late final String _pickerModeVariant;

  Map<String, Object> get _eventParams => {
    'placement': 'post_donation',
    AnalyticsEventConstants.paramExperimentName:
        OnboardingPickerModeExperiment.experimentName,
    AnalyticsEventConstants.paramVariantId: _pickerModeVariant,
  };

  @override
  void initState() {
    super.initState();
    _pickerModeVariant = OnboardingPickerModeExperiment.resolveVariant(
      ref.read(sharedPreferencesProvider),
    );
    _previewAnimation = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    Future.delayed(const Duration(milliseconds: 250), () {
      if (mounted) _previewAnimation.forward();
    });
    FirebaseAnalyticsService().logEvent(
      name: FirebaseAnalyticsService.eventOnboardingNotificationsPreviewShown,
      parameters: _eventParams,
    );
    // Tagged at screen level, not at picker-open: only ~27% open the picker,
    // and the guardrail that matters (onboarding completion) has to be
    // comparable across the whole screen audience.
    unawaited(
      FirebaseAnalyticsService().logEvent(
        name: AnalyticsEventConstants.onboardingExperimentExposure,
        parameters: _eventParams,
      ),
    );
  }

  @override
  void dispose() {
    _previewAnimation.dispose();
    super.dispose();
  }

  Future<void> _handleNotificationsPermission() async {
    if (!mounted) return;

    setState(() => _isProcessing = true);
    final handler = ref.read(firebaseMessagingProvider);

    // Request notification permission if not already granted
    var status = await Permission.notification.status;
    if (!status.isGranted) {
      // Soft-ask before the system prompt. Every iOS denial recorded here is
      // permanently_denied — the prompt never reappears and the end-screen
      // card can no longer recover that user — so a refusal caught in our own
      // dialog is far cheaper than one spent on the system's. Only users who
      // already tapped a chip or the CTA reach this, so it adds no step for
      // the people who skip the screen.
      unawaited(
        FirebaseAnalyticsService().logEvent(
          name: AnalyticsEventConstants.onboardingReminderPrimerShown,
          parameters: _eventParams,
        ),
      );
      final proceed = await showNotificationPermissionPrimer(context);
      if (!proceed) {
        unawaited(
          FirebaseAnalyticsService().logEvent(
            name: AnalyticsEventConstants.onboardingReminderPrimerDeclined,
            parameters: _eventParams,
          ),
        );
        // Must clear _isProcessing or the chips and CTA stay disabled and the
        // screen becomes the dead end this release is fixing.
        await recordReminderNotEnabled(ref.read(sharedPreferencesProvider));
        if (mounted) setState(() => _isProcessing = false);
        return;
      }
      if (!mounted) return;
      status = await Permission.notification.request();
    }

    if (!mounted) return;

    if (status.isGranted) {
      await handler.initialize(context, ref);

      // Log analytics event for permission granted in onboarding context
      await FirebaseAnalyticsService().logEvent(
        name: FirebaseAnalyticsService
            .eventOnboardingNotificationsPermissionGranted,
        parameters: _eventParams,
      );

      // Automatically set up reminders and advance
      await _setupRemindersAndAdvance();
    } else {
      // The chip already saved a time; without an explicit "off" that alone
      // reads as enabled and hides the end-screen reminder card from this user.
      // Written before the recovery flow below, which sets it true on success.
      await recordReminderNotEnabled(ref.read(sharedPreferencesProvider));

      // Permission denied - log analytics event for onboarding context
      if (status.isDenied || status.isPermanentlyDenied) {
        await FirebaseAnalyticsService().logEvent(
          name: FirebaseAnalyticsService
              .eventOnboardingNotificationsPermissionDenied,
          parameters: {
            ..._eventParams,
            'permission_status': status.isPermanentlyDenied
                ? 'permanently_denied'
                : 'denied',
          },
        );
      }

      // iOS only asks once: when the permission is permanently denied the
      // request() above returns instantly with no dialog, which used to leave
      // the tap with no visible effect. Explain that, offer settings, and if
      // they come back having granted it, carry on and set the reminder up
      // rather than dropping them back on an unchanged screen.
      if (status.isPermanentlyDenied && mounted) {
        final recovered = await _recoverBlockedPermission();
        if (recovered && mounted) {
          await handler.initialize(context, ref);
          await _setupRemindersAndAdvance();
          return;
        }
      }

      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  /// Permission is permanently denied, so no system prompt can be raised.
  /// Explain, offer the phone's settings, and report whether they came back
  /// having granted it. See [openSettingsAndAwaitPermission].
  Future<bool> _recoverBlockedPermission() async {
    const params = {AnalyticsEventConstants.paramSource: 'onboarding'};

    unawaited(
      FirebaseAnalyticsService().logEvent(
        name: AnalyticsEventConstants.notificationSettingsPromptShown,
        parameters: {..._eventParams, ...params},
      ),
    );

    final go = await showNotificationsBlockedDialog(context);
    if (!go) return false;

    unawaited(
      FirebaseAnalyticsService().logEvent(
        name: AnalyticsEventConstants.notificationSettingsOpened,
        parameters: {..._eventParams, ...params},
      ),
    );

    final granted = await openSettingsAndAwaitPermission();
    if (!granted) return false;

    unawaited(
      FirebaseAnalyticsService().logEvent(
        name: AnalyticsEventConstants.notificationPermissionRecovered,
        parameters: {..._eventParams, ...params},
      ),
    );
    return true;
  }

  Future<void> _setupRemindersAndAdvance() async {
    if (!mounted) return;

    final accepted = await PermissionHandler.requestNotificationPermission(
      context,
    );
    if (!accepted || !mounted) {
      setState(() => _isProcessing = false);
      return;
    }

    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setBool(SharedPreferenceConstants.dailyReminderEnabled, true);

    final savedHour = prefs.getInt(SharedPreferenceConstants.savedHours);
    final savedMinute = prefs.getInt(SharedPreferenceConstants.savedMinutes);
    final now = DateTime.now();
    DateTime anchorLocal;
    if (savedHour != null && savedMinute != null) {
      final candidate = DateTime(
        now.year,
        now.month,
        now.day,
        savedHour,
        savedMinute,
      );
      anchorLocal = candidate.isBefore(now)
          ? candidate.add(const Duration(days: 1))
          : candidate;
    } else {
      anchorLocal = now.add(const Duration(days: 1));
    }

    // Logged after the anchor is resolved rather than on entry, so the hour
    // reported is the one the reminder series is actually scheduled for. That
    // makes the two arms comparable: the chips arm reports the slot the user
    // chose, the control arm reports the silent "same time tomorrow" default.
    await FirebaseAnalyticsService().logEvent(
      name: FirebaseAnalyticsService.eventOnboardingReminderSetTap,
      parameters: {
        ..._eventParams,
        AnalyticsEventConstants.paramReminderSlot: ?_selectedSlot,
        AnalyticsEventConstants.paramReminderHour: anchorLocal.hour,
        AnalyticsEventConstants.paramReminderMinute: anchorLocal.minute,
      },
    );

    final scheduler = DailyRemindersScheduler(
      prefs: prefs,
      reminders: ref.read(reminderProvider),
    );
    await scheduler.scheduleSeriesFromAnchor(
      anchorLocal,
      l10n: AppLocalizations.of(context),
    );

    if (mounted) {
      await ref
          .read(reminderTimeProvider.notifier)
          .setTime(
            TimeOfDay(hour: anchorLocal.hour, minute: anchorLocal.minute),
          );
      setState(() => _isProcessing = false);
      _navigateNext();
    }
  }

  void _navigateNext() => widget.onNext?.call();

  /// Chips arm: persist the chosen slot time so [_setupRemindersAndAdvance]
  /// anchors the reminder series to it, then run the shared permission flow.
  Future<void> _onSlotSelected(String slot, TimeOfDay time) async {
    if (_isProcessing) return;
    _selectedSlot = slot;
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setInt(SharedPreferenceConstants.savedHours, time.hour);
    await prefs.setInt(SharedPreferenceConstants.savedMinutes, time.minute);
    await _handleNotificationsPermission();
  }

  /// Dismissing the picker used to return silently — no event, no navigation,
  /// an unchanged screen — so the tap looked like it had done nothing and the
  /// drop-off was invisible. Both ends are now logged, and a dismissal gets
  /// feedback pointing at the ways forward.
  Future<void> _onCustomTimeTap() async {
    if (_isProcessing) return;

    unawaited(
      FirebaseAnalyticsService().logEvent(
        name: AnalyticsEventConstants.onboardingReminderCustomTap,
        parameters: _eventParams,
      ),
    );

    // Dial won the picker-mode A/B (fewer back-outs than typed input). See
    // OnboardingPickerModeExperiment.
    final picked = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 7, minute: 0),
      initialEntryMode:
          _pickerModeVariant == OnboardingPickerModeExperiment.variantDial
          ? TimePickerEntryMode.dial
          : TimePickerEntryMode.input,
    );

    if (!mounted) return;

    if (picked == null) {
      unawaited(
        FirebaseAnalyticsService().logEvent(
          name: AnalyticsEventConstants.onboardingReminderCustomCancel,
          parameters: _eventParams,
        ),
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.reminderCustomCancelled),
        ),
      );
      return;
    }

    await _onSlotSelected('custom', picked);
  }

  String _notificationsTitle(AppLocalizations l10n) {
    switch (widget.intentIndex) {
      case 0:
        return l10n.enableNotificationsTitleLearn;
      case 1:
        return l10n.enableNotificationsTitleHabit;
      case 2:
        return l10n.enableNotificationsTitleStress;
      default:
        return l10n.enableNotificationsTitle;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final reminderTime = ref.watch(reminderTimeProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        top: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Smaller hero than the default onboarding pages so the preview and
            // the time options fit without scrolling on most phones.
            const headerFraction = 0.2;
            final headerHeight = widget.headerImage != null
                ? OnboardingHeaderImage.heightFor(
                    context,
                    fractionOverride: headerFraction,
                  )
                : 0.0;

            return SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (widget.headerImage != null)
                    OnboardingHeaderImage(
                      imagePath: widget.headerImage!,
                      heightFraction: headerFraction,
                    ),
                  OnboardingContent(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(
                        padding24,
                        padding24,
                        padding24,
                        padding16,
                      ),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: (constraints.maxHeight - 40 - headerHeight)
                              .clamp(0.0, double.infinity),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Laid out like the onboarding question pages: a
                            // left-aligned title, then a list of answers. The
                            // notification preview sits between the two as
                            // the thing the answer will schedule.
                            Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                OnboardingStepTitle(
                                  _notificationsTitle(l10n),
                                  style: context.text.headline,
                                ),
                                const SizedBox(height: 20),
                                // Decorative illustration: without the
                                // exclusion, screen readers read the mock
                                // card ("MEDITO", time, title, body) as if a
                                // real notification had arrived mid-screen.
                                ExcludeSemantics(
                                  child: _buildNotificationPreview(),
                                ),
                                const SizedBox(height: 28),
                                Text(
                                  l10n.reminderChipsQuestion,
                                  style: context.text.subtitle,
                                ),
                                // When a reminder already exists (e.g.
                                // re-entering onboarding) surface the time it's
                                // set for; the options below change it.
                                if (reminderTime != null) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    l10n.onboardingReminderCurrentlySet(
                                      reminderTime.format(context),
                                    ),
                                    style: context.text.muted.bodySmall,
                                  ),
                                ],
                                const SizedBox(height: 12),
                                _buildTimeOptions(l10n),
                              ],
                            ),
                            // Skip stays pinned toward the bottom.
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: TextButton(
                                style: TextButton.styleFrom(
                                  foregroundColor: Theme.of(context)
                                      .colorScheme
                                      .onSurface
                                      .withValues(alpha: 0.7),
                                ),
                                onPressed: () async {
                                  await FirebaseAnalyticsService().logEvent(
                                    name: FirebaseAnalyticsService
                                        .eventOnboardingReminderSkipTap,
                                    parameters: _eventParams,
                                  );
                                  _navigateNext();
                                },
                                child: Text(l10n.skipForNow),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  /// The mock notification, sliding in shortly after the page appears.
  Widget _buildNotificationPreview() {
    final curve = CurvedAnimation(
      parent: _previewAnimation,
      curve: Curves.easeOutCubic,
    );
    return FadeTransition(
      opacity: curve,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, -0.15),
          end: Offset.zero,
        ).animate(curve),
        child: _buildNotificationCard(),
      ),
    );
  }

  Widget _buildNotificationCard() {
    final l10n = AppLocalizations.of(context)!;
    final title = l10n.notificationPreviewTitleB;
    final body = l10n.notificationPreviewBodyB;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        // The card is white in both themes; the hairline keeps its edge on
        // the light theme's white page.
        border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: ColorConstants.accentDark,
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.center,
            child: SvgPicture.asset(
              'assets/images/ic_logo.svg',
              width: 26,
              height: 26,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: context.text.on(Colors.black).label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      l10n.notificationPreviewTimestamp,
                      style: context.text.on(Colors.black45).caption,
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  body,
                  style: context.text.on(Colors.black87).bodySmall,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// The three time-of-day presets and a custom-time option, as a list of
  /// full-width rows like the answers on the onboarding question pages.
  /// Picking one is an implementation intention: it anchors the reminder
  /// series to the chosen slot, and only then triggers the OS permission
  /// prompt.
  ///
  /// Rows rather than chips or side-by-side cards: the label and the time each
  /// get a full line's width, so nothing wraps or reflows whether the time
  /// reads "7:00 AM" or "07:00", in any locale and at any text scale. Custom
  /// is the last row with an arrow instead of a time, since it opens a picker
  /// rather than setting a reminder outright. Icons match the Settings
  /// reminder sheet so the two surfaces read as the same control.
  Widget _buildTimeOptions(AppLocalizations l10n) {
    final selected = ReminderSlot.forTime(ref.watch(reminderTimeProvider));
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return Column(
      children: [
        for (final slot in ReminderSlot.values) ...[
          _buildOptionRow(
            icon: MeditoIcon(
              assetName: switch (slot) {
                ReminderSlot.morning => MeditoIcons.sun,
                ReminderSlot.evening => MeditoIcons.bell,
                ReminderSlot.night => MeditoIcons.moon,
              },
              color: onSurface,
              size: 20,
            ),
            label: slot.label(l10n),
            trailing: Text(
              slot.time.format(context),
              style: context.text.muted.body,
            ),
            selected: selected == slot,
            onTap: () => _onSlotSelected(slot.analyticsId, slot.time),
          ),
          const SizedBox(height: 8),
        ],
        _buildOptionRow(
          icon: Icon(Icons.schedule_rounded, size: 20, color: onSurface),
          label: l10n.reminderSlotCustom,
          trailing: MeditoIcon(
            assetName: MeditoIcons.arrowRight,
            color: onSurface.withValues(alpha: 0.6),
            size: 18,
          ),
          selected: false,
          onTap: _onCustomTimeTap,
        ),
      ],
    );
  }

  Widget _buildOptionRow({
    required Widget icon,
    required String label,
    required Widget trailing,
    required bool selected,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(8),
      side: BorderSide(
        color: selected
            ? colorScheme.primary
            : colorScheme.outline.withAlpha(80),
        width: selected ? 1.5 : 1,
      ),
    );

    // Without the button role the row is announced as plain text. Disabled
    // and selected mirror its state for screen readers.
    return Semantics(
      button: true,
      enabled: !_isProcessing,
      selected: selected,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 150),
        opacity: _isProcessing ? 0.5 : 1,
        child: Material(
          color: selected ? colorScheme.primary.withAlpha(25) : theme.cardColor,
          shape: shape,
          child: InkWell(
            customBorder: shape,
            onTap: _isProcessing ? null : onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: padding16,
                vertical: 14,
              ),
              child: Row(
                children: [
                  icon,
                  const SizedBox(width: 12),
                  Expanded(child: Text(label, style: context.text.subtitle)),
                  const SizedBox(width: 12),
                  trailing,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
