// ignore_for_file: use_build_context_synchronously

import 'dart:async';

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
import 'package:medito/services/notifications/firebase_notifications_service.dart';
import 'package:medito/utils/notification_permission_flow.dart';
import 'package:medito/utils/permission_handler.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:medito/providers/shared_preference/shared_preference_provider.dart';
import 'package:medito/services/reminders/reminder_slots.dart';
import 'package:medito/services/reminders/smart_reminders_service.dart';
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

    final scheduler = SmartRemindersScheduler(
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

    // A/B: `input` is the mode that has always shipped and half of the people
    // who opened it backed out; `dial` is the Material default and needs no
    // typing. See OnboardingPickerModeExperiment.
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

  String _notificationsBody(AppLocalizations l10n) {
    switch (widget.intentIndex) {
      case 0:
        return l10n.enableNotificationsBodyLearn;
      case 1:
        return l10n.enableNotificationsBodyHabit;
      case 2:
        return l10n.enableNotificationsBodyStress;
      default:
        return l10n.enableNotificationsBody;
    }
  }

  @override
  Widget build(BuildContext context) {
    final reminderTime = ref.watch(reminderTimeProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        top: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final headerHeight = widget.headerImage != null
                ? OnboardingHeaderImage.heightFor(context)
                : 0.0;

            return SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (widget.headerImage != null)
                    OnboardingHeaderImage(imagePath: widget.headerImage!),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(32, 24, 32, 32),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: (constraints.maxHeight - 72 - headerHeight)
                            .clamp(0.0, double.infinity),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            children: [
                              Text(
                                _notificationsTitle(
                                  AppLocalizations.of(context)!,
                                ),
                                style: Theme.of(context).textTheme.displayLarge
                                    ?.copyWith(
                                      fontSize: 24,
                                      fontWeight: FontWeight.w600,
                                    ),
                                textAlign: TextAlign.center,
                              ),
                              // Before a reminder is set the body line is
                              // dropped — the title plus the "When will you
                              // meditate?" question above the chips carry the
                              // message, one message per block instead of two.
                              if (reminderTime != null) ...[
                                const SizedBox(height: 16),
                                Text(
                                  _notificationsBody(
                                    AppLocalizations.of(context)!,
                                  ),
                                  style: Theme.of(context).textTheme.bodyMedium
                                      ?.copyWith(fontSize: 16, height: 1.5),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 24),
                          _buildNotificationPreview(context),
                          const SizedBox(height: 32),
                          Column(
                            children: [
                              if (reminderTime != null)
                                _buildConfirmReminderButton()
                              else
                                _buildTimeChips(AppLocalizations.of(context)!),
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                child: TextButton(
                                  onPressed: () async {
                                    // Log analytics event for skip tap
                                    await FirebaseAnalyticsService().logEvent(
                                      name: FirebaseAnalyticsService
                                          .eventOnboardingReminderSkipTap,
                                      parameters: _eventParams,
                                    );
                                    _navigateNext();
                                  },
                                  child: Text(
                                    AppLocalizations.of(context)!.skipForNow,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
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

  Widget _buildNotificationPreview(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final phoneBorder = isDark
        ? Colors.white.withValues(alpha: 0.18)
        : Colors.black87;
    const phoneWidth = 280.0;
    const cardOverhang = 36.0;

    return SizedBox(
      height: 170,
      child: ClipRect(
        clipper: _BottomOnlyClipper(),
        child: OverflowBox(
          maxHeight: 600,
          maxWidth: double.infinity,
          alignment: Alignment.topCenter,
          child: SizedBox(
            width: phoneWidth,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.topCenter,
              children: [
                Container(
                  width: phoneWidth,
                  height: 560,
                  decoration: BoxDecoration(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(44),
                    ),
                    border: Border.all(color: phoneBorder, width: 3),
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.02)
                        : Colors.white,
                  ),
                ),
                Positioned(
                  top: 56,
                  left: -cardOverhang,
                  right: -cardOverhang,
                  child: FadeTransition(
                    opacity: CurvedAnimation(
                      parent: _previewAnimation,
                      curve: Curves.easeOutCubic,
                    ),
                    child: SlideTransition(
                      position:
                          Tween<Offset>(
                            begin: const Offset(0, -0.04),
                            end: Offset.zero,
                          ).animate(
                            CurvedAnimation(
                              parent: _previewAnimation,
                              curve: Curves.easeOutCubic,
                            ),
                          ),
                      child: _buildNotificationCard(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNotificationCard() {
    final l10n = AppLocalizations.of(context)!;
    final title = l10n.notificationPreviewTitleB;
    final body = l10n.notificationPreviewBodyB;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.28),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: ColorConstants.lightPurple,
              borderRadius: BorderRadius.circular(8),
            ),
            alignment: Alignment.center,
            child: SvgPicture.asset(
              'assets/images/ic_logo.svg',
              width: 22,
              height: 22,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'MEDITO',
                        style: TextStyle(
                          color: Colors.black54,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ),
                    Text(
                      l10n.notificationPreviewTimestamp,
                      style: const TextStyle(
                        color: Colors.black45,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 1),
                Text(
                  body,
                  style: const TextStyle(
                    color: Colors.black87,
                    fontSize: 12,
                    height: 1.3,
                  ),
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

  /// Chips arm: "When will you meditate?" + three time-of-day chips and a
  /// custom-time option. Picking one is an implementation intention — it
  /// anchors the reminder series to the chosen slot instead of the silent
  /// "same time tomorrow" default, and only then triggers the OS permission
  /// prompt.
  /// Three time presets on ONE row, plus a full-width "pick my own time"
  /// button underneath.
  ///
  /// This was four ActionChips in a Wrap. Chips inherit `labelLarge`, which
  /// this app's text theme overrides to 20sp with 0.8 letter-spacing (it is
  /// meant for shortcut titles), so a single chip came out ~270pt wide and the
  /// Wrap put every one on its own line — four stacked rows, in every locale
  /// and at every text scale, which is what pushed the screen into scrolling.
  /// Equal-width cards with the label above the time are immune to that: the
  /// layout is the same three columns whether the time reads "7:00 AM" or
  /// "07:00", and a long label (es: "Antes de dormir") wraps inside its own
  /// card instead of reflowing the row.
  ///
  /// Custom is deliberately NOT a fourth card. It opens a different kind of
  /// interaction, and giving it the full width both reflects that and keeps
  /// the presets visually a set of three. Icons match the Settings reminder
  /// sheet so the two surfaces read as the same control.
  Widget _buildTimeChips(AppLocalizations l10n) {
    return Column(
      children: [
        Text(
          l10n.reminderChipsQuestion,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(fontSize: 16, height: 1.5),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final slot in ReminderSlot.values) ...[
                if (slot != ReminderSlot.values.first) const SizedBox(width: 8),
                Expanded(child: _buildSlotCard(l10n, slot)),
              ],
            ],
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _isProcessing ? null : _onCustomTimeTap,
            icon: const Icon(Icons.schedule_rounded, size: 20),
            label: Text(
              l10n.reminderSlotCustom,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSlotCard(AppLocalizations l10n, ReminderSlot slot) {
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: _isProcessing
          ? null
          : () => _onSlotSelected(slot.analyticsId, slot.time),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: onSurface.withValues(alpha: 0.24)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            MeditoIcon(
              assetName: switch (slot) {
                ReminderSlot.morning => MeditoIcons.sun,
                ReminderSlot.evening => MeditoIcons.bell,
                ReminderSlot.night => MeditoIcons.moon,
              },
              color: onSurface,
              size: 20,
            ),
            const SizedBox(height: 8),
            Text(
              slot.label(l10n),
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                height: 1.2,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              slot.time.format(context),
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontSize: 13,
                height: 1.2,
                color: onSurface.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConfirmReminderButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: () async {
          await FirebaseAnalyticsService().logEvent(
            name: FirebaseAnalyticsService.eventOnboardingReminderConfirmTap,
            parameters: _eventParams,
          );
          _navigateNext();
        },
        child: Text(AppLocalizations.of(context)!.setReminderB),
      ),
    );
  }
}

/// Clips only the bottom of a widget, leaving horizontal overflow intact so
/// the notification card can overhang the phone frame without being clipped.
class _BottomOnlyClipper extends CustomClipper<Rect> {
  @override
  Rect getClip(Size size) =>
      Rect.fromLTRB(-10000, 0, size.width + 10000, size.height);

  @override
  bool shouldReclip(covariant CustomClipper<Rect> oldClipper) => false;
}
