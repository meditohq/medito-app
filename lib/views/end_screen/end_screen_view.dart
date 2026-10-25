import 'package:medito/widgets/adaptive/adaptive_page_body.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:medito/constants/constants.dart';
import 'package:medito/constants/strings/analytics_event_constants.dart';
import 'package:medito/constants/icons/medito_icons.dart';
import 'package:medito/l10n/app_localizations.dart';
import 'package:medito/models/local_all_stats.dart';
import 'package:medito/models/local_audio_completed.dart';
import 'package:medito/models/models.dart';
import 'package:medito/models/timer/timer_session.dart';
import 'package:medito/providers/notification/reminder_provider.dart';
import 'package:medito/providers/providers.dart';
import 'package:medito/providers/settings/account_prompt_provider.dart';
import 'package:medito/providers/stats_provider.dart';
import 'package:medito/services/analytics/firebase_analytics_service.dart';
import 'package:medito/services/reminders/daily_reminders_service.dart';
import 'package:medito/utils/logger.dart';
import 'package:medito/utils/notification_permission_flow.dart';
import 'package:medito/utils/permission_handler.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:medito/views/bottom_navigation/bottom_navigation_bar_view.dart';
import 'package:medito/views/settings/sign_up_log_in_screen.dart';
import 'package:medito/views/settings/widgets/reminder_tile.dart'
    show
        ReminderChoice,
        ReminderChoiceCustom,
        ReminderChoiceOff,
        ReminderChoiceSlot,
        ReminderOptionsSheet;
import 'package:medito/views/player/widgets/bottom_actions/bottom_action_bar.dart';
import 'package:medito/views/root/root_page_view.dart';
import 'package:medito/widgets/medito_icon.dart';
import 'package:medito/widgets/snackbar_widget.dart';

import 'widgets/account_prompt_card.dart';
import 'widgets/animated_end_screen_section.dart';
import 'widgets/donation_widget.dart';
import 'widgets/soft_ask_card.dart';
import 'widgets/zen_mode_animation.dart';
import 'restored_when.dart';

/// Tags every end-screen prompt event with where it came from, so they can be
/// swept with `source = 'end_screen'` alongside the events shared with other
/// surfaces (notifications_enabled, onboarding_signup_completed, ...).
const _endScreenSourceParams = <String, Object>{
  AnalyticsEventConstants.paramSource: AnalyticsEventConstants.sourceEndScreen,
};

class EndScreenView extends ConsumerStatefulWidget {
  final PlaybackRequest request;

  /// Snapshot of stats taken in PlayerView before this session affected them.
  /// Displayed on entry so the streak number animates from old -> current
  /// once the entrance slide completes. Null on first-ever session.
  final LocalAllStats? priorStats;

  /// Set when this end screen is rebuilt on a later launch (the app was killed
  /// before it could open): when the session finished. The screen then says
  /// which session it is about and offers one plain way back to Home.
  final DateTime? restoredFrom;

  const EndScreenView({
    super.key,
    required this.request,
    this.priorStats,
    this.restoredFrom,
  });

  @override
  ConsumerState<EndScreenView> createState() => _EndScreenViewState();
}

class _EndScreenViewState extends ConsumerState<EndScreenView>
    with TickerProviderStateMixin {
  final _animatedSwitcherKey = GlobalKey();
  final _analytics = FirebaseAnalyticsService();

  // While true, render stats from widget.priorStats. Flipped to false after
  // the entrance slide finishes — that frame change is what triggers the
  // AnimatedSwitcher transition from old streak -> new streak.
  bool _showPriorStats = true;
  bool _animationsStarted = false;
  bool _reminderPromptImpressionLogged = false;
  bool _accountPromptImpressionLogged = false;

  /// Whether the OS notification permission is already granted. When it is,
  /// tapping the CTA raises no system dialog, so the soft-ask is skipped.
  bool _notificationsGranted = false;

  /// Permission is permanently denied, so no system prompt can be raised and
  /// the phone's settings are the only way back. The card says so rather than
  /// offering a button that silently bounces the user out to settings.
  bool _notificationsBlocked = false;

  late AnimationController _statsAnimationController;
  late AnimationController _reminderAnimationController;
  late AnimationController _cardAnimationController;

  late Animation<Offset> _statsSlideAnimation;
  late Animation<double> _statsFadeAnimation;
  late Animation<Offset> _reminderSlideAnimation;
  late Animation<double> _reminderFadeAnimation;
  late Animation<Offset> _cardSlideAnimation;
  late Animation<double> _cardFadeAnimation;

  @override
  void initState() {
    super.initState();
    _logScreenView();
    _checkNotificationPermission();

    _statsAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _reminderAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _cardAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _statsSlideAnimation =
        Tween<Offset>(begin: const Offset(0, -0.3), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _statsAnimationController,
            curve: Curves.easeOutCubic,
          ),
        );

    _statsFadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _statsAnimationController, curve: Curves.easeOut),
    );

    _reminderSlideAnimation =
        Tween<Offset>(begin: const Offset(0, -0.3), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _reminderAnimationController,
            curve: Curves.easeOutCubic,
          ),
        );

    _reminderFadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _reminderAnimationController,
        curve: Curves.easeOut,
      ),
    );

    _cardSlideAnimation =
        Tween<Offset>(begin: const Offset(0, -0.3), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _cardAnimationController,
            curve: Curves.easeOutCubic,
          ),
        );

    _cardFadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _cardAnimationController, curve: Curves.easeOut),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Here rather than initState: reduce motion is read from MediaQuery.
    if (!_animationsStarted) {
      _animationsStarted = true;
      _startAnimations();
    }
  }

  void _startAnimations() {
    // Reduce motion: show everything in place, with the current stats.
    if (MediaQuery.disableAnimationsOf(context)) {
      _statsAnimationController.value = 1;
      _reminderAnimationController.value = 1;
      _cardAnimationController.value = 1;
      _showPriorStats = false;
      return;
    }

    _statsAnimationController.forward();
    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) {
        _reminderAnimationController.forward();
      }
    });
    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted) {
        _cardAnimationController.forward();
      }
    });

    // Skip the prior->current transition if we never got a snapshot (e.g.
    // first-ever session) — there's nothing to animate from.
    if (widget.priorStats == null) {
      _showPriorStats = false;
      return;
    }

    // Once the entrance slide settles, swap the displayed stats to the
    // current values. The streak AnimatedSwitcher picks up the value change
    // and animates from the old number to the new one.
    Future.delayed(const Duration(milliseconds: 700), () {
      if (mounted) {
        setState(() => _showPriorStats = false);
      }
    });
  }

  @override
  void dispose() {
    _statsAnimationController.dispose();
    _reminderAnimationController.dispose();
    _cardAnimationController.dispose();
    super.dispose();
  }

  Future<void> _logScreenView() async {
    await _analytics.logScreenView(screenName: 'EndScreenView');
  }

  void _navigateToHome() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (context) =>
            const RootPageView(firstChild: BottomNavigationBarView()),
      ),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      bottomNavigationBar: widget.restoredFrom != null
          ? _buildRestoredDoneBar()
          : BottomActionBar(
              leftItem: BottomActionBarItem(
                child: MeditoIcon(
                  assetName: MeditoIcons.xmark,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
                onTap: () => Navigator.pop(context),
                semanticLabel: AppLocalizations.of(context)!.close,
              ),
              // No centre items: null leaves the same 48pt spacers, where
              // empty items were read as two unlabelled disabled buttons.
              rightItem: BottomActionBarItem(
                child: MeditoIcon(
                  assetName: MeditoIcons.home,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
                onTap: _navigateToHome,
                semanticLabel: AppLocalizations.of(context)!.home,
              ),
              layout: BottomActionBarLayout.edgeAligned,
            ),
      body: AdaptivePageBody(
        maxWidth: 640,
        child: SingleChildScrollView(
          child: SafeArea(
            child: Column(
              children: [
                if (widget.restoredFrom != null)
                  FadeTransition(
                    opacity: _statsFadeAnimation,
                    child: _buildRestoredContext(widget.restoredFrom!),
                  ),
                SlideTransition(
                  position: _statsSlideAnimation,
                  child: FadeTransition(
                    opacity: _statsFadeAnimation,
                    child: ref.watch(zenModeProvider)
                        ? const ZenModeAnimation()
                        : _buildStatsArea(),
                  ),
                ),
                SlideTransition(
                  position: _reminderSlideAnimation,
                  child: FadeTransition(
                    opacity: _reminderFadeAnimation,
                    // The reminder and account soft-asks are mutually exclusive
                    // (see shouldShowAccountPromptProvider), so they share this
                    // animation slot; only one ever renders.
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AnimatedEndScreenSection(child: _buildReminderPrompt()),
                        AnimatedEndScreenSection(child: _buildAccountPrompt()),
                      ],
                    ),
                  ),
                ),
                SlideTransition(
                  position: _cardSlideAnimation,
                  child: FadeTransition(
                    opacity: _cardFadeAnimation,
                    child: _buildCard(),
                  ),
                ),
                // _buildFreezeRewardBanner(ref.watch(statsProvider).valueOrNull!),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// "Welcome back. You finished “Body scan” last night.": without it, an end
  /// screen that appears on opening the app the next morning makes no sense.
  Widget _buildRestoredContext(DateTime completedAt) {
    final l10n = AppLocalizations.of(context)!;
    final when = restoredWhen(
      completedAt,
      DateTime.now(),
      dayBoundary: Duration(
        hours:
            ref
                .read(sharedPreferencesProvider)
                .getInt(SharedPreferenceConstants.dayBoundaryOffsetHours) ??
            0,
      ),
    );
    final request = widget.request;
    final String text;
    if (request.isTimer) {
      final minutes = (request.duration / 60000).round().clamp(1, 1 << 20);
      text = switch (when) {
        RestoredWhen.lastNight => l10n.endScreenRestoredTimerLastNight(minutes),
        RestoredWhen.earlierToday => l10n.endScreenRestoredTimerEarlierToday(
          minutes,
        ),
        RestoredWhen.yesterday => l10n.endScreenRestoredTimerYesterday(minutes),
      };
    } else {
      text = switch (when) {
        RestoredWhen.lastNight => l10n.endScreenRestoredLastNight(
          request.title,
        ),
        RestoredWhen.earlierToday => l10n.endScreenRestoredEarlierToday(
          request.title,
        ),
        RestoredWhen.yesterday => l10n.endScreenRestoredYesterday(
          request.title,
        ),
      };
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(padding24, padding16, padding24, 0),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
          fontFamily: googleSans,
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
        ),
      ),
    );
  }

  /// Home is underneath a restored end screen, so close and home are the same
  /// action; one labelled button reads more clearly than two icons. Outlined so
  /// it doesn't compete with the filled asks on the screen.
  Widget _buildRestoredDoneBar() {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    // Not AdaptivePageBody: its Align fills the height it's given, which in the
    // bottomNavigationBar slot is the whole screen. heightFactor keeps the bar
    // as tall as the button.
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.all(padding16),
      child: Center(
        heightFactor: 1,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640 - 2 * padding16),
          child: SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => Navigator.pop(context),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                side: BorderSide(color: onSurface.withValues(alpha: 0.5)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                AppLocalizations.of(context)!.endScreenDone,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontFamily: googleSans,
                  fontWeight: FontWeight.w500,
                  color: onSurface,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Padding _buildCard() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: padding16),
      child: DonationWidget(),
    );
  }

  Widget _buildStatsArea() {
    final statsAsyncValue = ref.watch(statsProvider);
    // Use the pre-session snapshot for the first beat after the entrance
    // slide, then fall back to the live stats so AnimatedSwitcher animates.
    final displayedStats = _showPriorStats && widget.priorStats != null
        ? AsyncValue<LocalAllStats>.data(widget.priorStats!)
        : statsAsyncValue;

    final l10n = AppLocalizations.of(context)!;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    return displayedStats.when(
      loading: () => SizedBox(
        height: 200,
        child: Center(
          child: CircularProgressIndicator(semanticsLabel: l10n.loading),
        ),
      ),
      error: (err, _) {
        AppLogger.e('END_SCREEN', 'Failed to load stats: $err');
        return SizedBox(
          height: 200,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: padding24),
              child: Text(l10n.anErrorOccurred, textAlign: TextAlign.center),
            ),
          ),
        );
      },
      data: (localAllStats) {
        var streak = localAllStats.streakCurrent;
        // The number animates from the prior streak; say the current one
        // straight away rather than the old value for the first 700 ms.
        final spokenStreak = statsAsyncValue.value?.streakCurrent ?? streak;
        var daysMeditated = _getDaysMeditated(localAllStats.audioCompleted);
        var lastFiveDays = List.generate(
          5,
          (index) => DateTime.now().subtract(Duration(days: index)),
        );

        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedSwitcher(
              key: _animatedSwitcherKey,
              duration: reduceMotion
                  ? Duration.zero
                  : const Duration(milliseconds: 500),
              transitionBuilder: (Widget child, Animation<double> animation) {
                return FadeTransition(
                  opacity: animation,
                  child: ScaleTransition(
                    scale: Tween<double>(begin: 0.8, end: 1.0).animate(
                      CurvedAnimation(
                        parent: animation,
                        curve: Curves.easeOutBack,
                      ),
                    ),
                    child: child,
                  ),
                );
              },
              // Read with the caption below as one phrase, "5 day streak".
              child: ExcludeSemantics(
                key: ValueKey<int>(streak),
                child: Text(
                  streak.toString(),
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontFamily: googleSans,
                    fontSize: 100,
                    fontWeight: FontWeight.w400,
                  ),
                  textAlign: TextAlign.left,
                ),
              ),
            ),
            Text(
              l10n.dayStreak,
              semanticsLabel: l10n.streakDays(spokenStreak),
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                fontFamily: googleSans,
                fontSize: 40,
                fontWeight: FontWeight.w400,
                height: 1,
                color: context.brandAccent,
              ),
              textAlign: TextAlign.left,
            ),
            const SizedBox(height: 24),
            AnimatedSwitcher(
              duration: reduceMotion
                  ? Duration.zero
                  : const Duration(seconds: 1),
              child: _buildDayLettersAndIcons(
                lastFiveDays,
                daysMeditated,
                key: ValueKey(daysMeditated.join()),
              ),
            ),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Text(
                AppLocalizations.of(context)!.dailyPracticeMessage,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontFamily: googleSans,
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                  height: 1.3,
                ),
              ),
            ),
            const SizedBox(height: 40),
          ],
        );
      },
    );
  }

  List<String> _getDaysMeditated(List<LocalAudioCompleted>? audioCompleted) {
    return audioCompleted
            ?.map(
              (audio) => DateTime.fromMillisecondsSinceEpoch(
                audio.timestamp,
              ).toIso8601String().split('T')[0],
            )
            .toList() ??
        [];
  }

  List<String> _getDaysWithStreakFreeze(LocalAllStats stats) {
    return stats.freezeUsageDates
        .map(
          (timestamp) => DateTime.fromMillisecondsSinceEpoch(
            timestamp,
          ).toIso8601String().split('T')[0],
        )
        .toList();
  }

  Widget _buildDayLettersAndIcons(
    List<DateTime> lastFiveDays,
    List<String> daysMeditated, {
    Key? key,
  }) {
    lastFiveDays = lastFiveDays.reversed.toList();

    final statsData = _showPriorStats && widget.priorStats != null
        ? widget.priorStats
        : ref.watch(statsProvider).value;
    var daysWithFreeze = statsData != null
        ? _getDaysWithStreakFreeze(statsData)
        : <String>[];

    var dayLetters = lastFiveDays.map((day) {
      switch (day.weekday) {
        case 1:
          return AppLocalizations.of(context)!.monday;
        case 2:
          return AppLocalizations.of(context)!.tuesday;
        case 3:
          return AppLocalizations.of(context)!.wednesday;
        case 4:
          return AppLocalizations.of(context)!.thursday;
        case 5:
          return AppLocalizations.of(context)!.friday;
        case 6:
          return AppLocalizations.of(context)!.saturday;
        case 7:
          return AppLocalizations.of(context)!.sunday;
        default:
          return '';
      }
    }).toList();

    return Row(
      key: key,
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(dayLetters.length, (index) {
        var day = lastFiveDays[index];
        var dayString = day.toIso8601String().split('T')[0];
        var isMeditated = daysMeditated.contains(dayString);
        var isFreeze = daysWithFreeze.contains(dayString);

        var isConsecutive =
            (isMeditated || isFreeze) &&
            (index > 0 &&
                    (daysMeditated.contains(
                          lastFiveDays[index - 1].toIso8601String().split(
                            'T',
                          )[0],
                        ) ||
                        daysWithFreeze.contains(
                          lastFiveDays[index - 1].toIso8601String().split(
                            'T',
                          )[0],
                        )) ||
                index < dayLetters.length - 1 &&
                    (daysMeditated.contains(
                          lastFiveDays[index + 1].toIso8601String().split(
                            'T',
                          )[0],
                        ) ||
                        daysWithFreeze.contains(
                          lastFiveDays[index + 1].toIso8601String().split(
                            'T',
                          )[0],
                        )));

        final l10n = AppLocalizations.of(context)!;
        // A lone weekday letter and an unlabelled icon told screen readers
        // nothing; say the day and whether it counted.
        final daySemantics =
            '${DateFormat.EEEE(Localizations.localeOf(context).toString()).format(day)}, '
            '${isFreeze
                ? l10n.streakFreezeUsed
                : isMeditated
                ? l10n.dayMeditated
                : l10n.dayNotMeditated}';

        return Semantics(
          label: daySemantics,
          excludeSemantics: true,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  dayLetters[index],
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontFamily: googleSans,
                    fontSize: 14,
                    fontWeight: (isMeditated || isFreeze)
                        ? FontWeight.w600
                        : FontWeight.w500,
                    height: 1.2,
                    color: isFreeze
                        ? ColorConstants.graphite
                        : isMeditated
                        ? context.brandAccent
                        : ColorConstants.moon,
                  ),
                ),
                const SizedBox(height: 4),
                SizedBox(
                  width: 36,
                  height: 36,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isConsecutive
                                ? Theme.of(context).colorScheme.onSurface
                                      .withValues(alpha: 0.12)
                                : Colors.transparent,
                            width: 2,
                          ),
                        ),
                      ),
                      if (isFreeze)
                        MeditoIcon(
                          assetName: MeditoIcons.snow,
                          size: 32,
                          color: ColorConstants.graphite,
                        )
                      else if (isMeditated)
                        MeditoIcon(
                          assetName: MeditoIcons.checkCircleSolid,
                          size: 32,
                          color: context.brandAccent,
                        )
                      else
                        _buildCircle(32, ColorConstants.moon),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }

  Widget _buildCircle(double size, Color colour) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: colour),
    );
  }

  Future<void> _dismissReminderPromptForever() async {
    await ref.read(reminderPromptDismissedProvider.notifier).dismissForever();
    unawaited(
      ref
          .read(analyticsServiceProvider)
          .logEvent(
            name: AnalyticsEventConstants.endScreenReminderPromptDismissed,
            parameters: _endScreenSourceParams,
          ),
    );
    if (mounted) {
      showSnackBar(
        context,
        AppLocalizations.of(context)!.reminderPromptDismissedMessage,
      );
    }
  }

  Widget _buildReminderPrompt() {
    // shouldShowReminderPromptProvider is false whenever reminders are on, so
    // this card only ever renders in the "off" state and vanishes on success.
    final shouldShow = ref.watch(shouldShowReminderPromptProvider);

    if (!shouldShow) {
      return const SizedBox.shrink();
    }

    if (!_reminderPromptImpressionLogged) {
      _reminderPromptImpressionLogged = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          unawaited(
            ref
                .read(analyticsServiceProvider)
                .logEvent(
                  name: AnalyticsEventConstants.endScreenReminderPromptShown,
                  parameters: _endScreenSourceParams,
                ),
          );
        }
      });
    }

    final l10n = AppLocalizations.of(context)!;
    return SoftAskCard(
      title: l10n.dailyReminders,
      body: l10n.enableNotificationsBody,
      ctaLabel: _notificationsBlocked
          ? l10n.turnOnInSettings
          : l10n.turnOnReminders,
      onCta: _enableReminders,
      onSnooze: _snoozeReminderPrompt,
      onDismiss: _dismissReminderPromptForever,
    );
  }

  /// End-screen soft-ask inviting an anonymous user to attach an email so their
  /// streak and history survive a reinstall or a new phone. Gated by
  /// [shouldShowAccountPromptProvider]; shares the reminder animation slot.
  Widget _buildAccountPrompt() {
    final shouldShow = ref.watch(shouldShowAccountPromptProvider);
    if (!shouldShow) {
      return const SizedBox.shrink();
    }

    if (!_accountPromptImpressionLogged) {
      _accountPromptImpressionLogged = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          unawaited(
            ref
                .read(analyticsServiceProvider)
                .logEvent(
                  name: AnalyticsEventConstants.endScreenAccountPromptShown,
                  parameters: _endScreenSourceParams,
                ),
          );
        }
      });
    }

    return AccountPromptCard(
      onSave: _openAccountConversion,
      onSnooze: _snoozeAccountPrompt,
      onDismiss: _dismissAccountPromptForever,
    );
  }

  /// Opens the existing sign-in sheet to link an email to the current
  /// (anonymous) account. Uses `fromSettings: true` so a successful link pops
  /// back to this end screen instead of restarting onboarding. The account-
  /// forking fix (deployed 2026-09-02) means the server reuses this client_id,
  /// so local stats are preserved rather than wiped.
  Future<void> _openAccountConversion() async {
    unawaited(
      ref
          .read(analyticsServiceProvider)
          .logEvent(
            name: AnalyticsEventConstants.endScreenAccountPromptTapped,
            parameters: _endScreenSourceParams,
          ),
    );

    // Make sure the session that just finished is on the server before we link
    // the email, so nothing done pre-conversion is left behind.
    unawaited(ref.read(statsManagerProvider).sync(force: true));

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const SignUpLogInPage(
          fromSettings: true,
          source: AnalyticsEventConstants.sourceEndScreen,
        ),
      ),
    );

    if (!mounted) return;
    // Refresh identity + stats so the card disappears once an email is attached.
    ref.invalidate(meProvider);
    ref.read(statsProvider.notifier).refresh();
  }

  Future<void> _snoozeAccountPrompt() async {
    await ref.read(accountPromptDismissedProvider.notifier).snooze();
  }

  Future<void> _dismissAccountPromptForever() async {
    await ref.read(accountPromptDismissedProvider.notifier).dismissForever();
  }

  Future<void> _checkNotificationPermission() async {
    final status = await Permission.notification.status;
    if (mounted) {
      setState(() {
        _notificationsGranted = status.isGranted;
        _notificationsBlocked = status.isPermanentlyDenied;
      });
    }
  }

  /// Permission is permanently denied: explain, offer the phone's settings,
  /// and if they come back having granted it, finish enabling the reminder so
  /// they do not have to find this card and tap it a second time.
  ///
  /// Returns true if permission is now granted.
  Future<bool> _recoverBlockedPermission() async {
    final analytics = ref.read(analyticsServiceProvider);
    const params = _endScreenSourceParams;

    unawaited(
      analytics.logEvent(
        name: AnalyticsEventConstants.notificationSettingsPromptShown,
        parameters: params,
      ),
    );

    final go = await showNotificationsBlockedDialog(context);
    if (!go) return false;

    unawaited(
      analytics.logEvent(
        name: AnalyticsEventConstants.notificationSettingsOpened,
        parameters: params,
      ),
    );

    final granted = await openSettingsAndAwaitPermission();
    if (!mounted) return false;

    setState(() {
      _notificationsGranted = granted;
      _notificationsBlocked = !granted;
    });

    if (!granted) return false;

    unawaited(
      analytics.logEvent(
        name: AnalyticsEventConstants.notificationPermissionRecovered,
        parameters: params,
      ),
    );
    return true;
  }

  Future<void> _snoozeReminderPrompt() async {
    await ref.read(reminderPromptDismissedProvider.notifier).snooze();
    unawaited(
      ref
          .read(analyticsServiceProvider)
          .logEvent(
            name: AnalyticsEventConstants.endScreenReminderPromptSnoozed,
            parameters: _endScreenSourceParams,
          ),
    );
  }

  /// Logs the soft-ask funnel around [showNotificationPermissionPrimer].
  Future<bool> _confirmPermissionPrompt() async {
    unawaited(
      ref
          .read(analyticsServiceProvider)
          .logEvent(
            name: AnalyticsEventConstants.endScreenReminderPrimerShown,
            parameters: _endScreenSourceParams,
          ),
    );

    final proceed = await showNotificationPermissionPrimer(context);

    if (!proceed) {
      unawaited(
        ref
            .read(analyticsServiceProvider)
            .logEvent(
              name: AnalyticsEventConstants.endScreenReminderPrimerDeclined,
              parameters: _endScreenSourceParams,
            ),
      );
      return false;
    }
    return true;
  }

  /// The same Morning / Evening / Night / Custom sheet as the Settings tile.
  /// Returns the chosen time and the slot id for analytics, or null if the
  /// user closed the sheet (or the custom picker) without choosing.
  Future<(TimeOfDay, String)?> _pickReminderTime() async {
    final analytics = ref.read(analyticsServiceProvider);
    unawaited(
      analytics.logEvent(
        name: AnalyticsEventConstants.endScreenReminderSheetShown,
        parameters: _endScreenSourceParams,
      ),
    );

    final choice = await showModalBottomSheet<ReminderChoice>(
      context: context,
      showDragHandle: true,
      backgroundColor: Theme.of(context).bottomSheetTheme.backgroundColor,
      // Reminders are off whenever this card offers to turn them on, so the
      // sheet never shows its "Turn off" row here.
      builder: (_) => const ReminderOptionsSheet(current: null, enabled: false),
    );
    if (!mounted) return null;

    (TimeOfDay, String)? result;
    switch (choice) {
      case ReminderChoiceSlot(:final slot):
        result = (slot.time, slot.analyticsId);
      case ReminderChoiceCustom():
        final picked = await showTimePicker(
          context: context,
          initialTime: const TimeOfDay(hour: 7, minute: 0),
          initialEntryMode: TimePickerEntryMode.input,
        );
        if (picked != null) result = (picked, 'custom');
      case ReminderChoiceOff():
      case null:
        result = null;
    }

    if (result == null) {
      unawaited(
        analytics.logEvent(
          name: AnalyticsEventConstants.endScreenReminderSheetDismissed,
          parameters: _endScreenSourceParams,
        ),
      );
    }
    return result;
  }

  Future<void> _enableReminders() async {
    try {
      // No system prompt is coming for these users — route them to settings
      // instead of raising a dialog that cannot appear. Done before the time
      // sheet so someone who won't grant permission never picks a time for
      // nothing; if they come back with it granted, the sheet follows.
      if (_notificationsBlocked) {
        final recovered = await _recoverBlockedPermission();
        if (!recovered || !mounted) return;
      }

      // Time first, permission second — same order as onboarding's chips and
      // the Settings tile. Replaces the old silent "same time tomorrow"
      // default that the other two surfaces had already dropped.
      final pick = await _pickReminderTime();
      if (pick == null || !mounted) return;
      final (time, slotId) = pick;

      if (!_notificationsGranted) {
        // Only worth asking when a system dialog is actually coming; if
        // permission is already granted this just adds a tap.
        final proceed = await _confirmPermissionPrompt();
        if (!proceed || !mounted) return;
      }

      final accepted = await PermissionHandler.requestNotificationPermission(
        context,
      );
      if (!accepted) {
        unawaited(
          ref
              .read(analyticsServiceProvider)
              .logEvent(
                name: AnalyticsEventConstants.endScreenReminderOsDenied,
                parameters: _endScreenSourceParams,
              ),
        );
        return;
      }
      if (!mounted) return;

      final prefs = ref.read(sharedPreferencesProvider);
      final service = DailyRemindersService(
        prefs: prefs,
        reminders: ref.read(reminderProvider),
      );

      final anchor = await service.enableAt(
        time,
        l10n: AppLocalizations.of(context),
      );
      await ref.read(reminderEnabledProvider.notifier).setEnabled(true);
      await ref.read(reminderTimeProvider.notifier).setTime(time);

      // The card vanishes on success; say what was set so it isn't silent.
      if (mounted) {
        showSnackBar(
          context,
          AppLocalizations.of(context)!.reminderSetFor(time.format(context)),
        );
      }

      unawaited(
        ref
            .read(analyticsServiceProvider)
            .logEvent(
              name: AnalyticsEventConstants.notificationsEnabled,
              parameters: {
                AnalyticsEventConstants.paramSource:
                    AnalyticsEventConstants.sourceEndScreen,
                // Same params as the onboarding set-tap and the Settings tile
                // so all three surfaces are comparable.
                AnalyticsEventConstants.paramReminderSlot: slotId,
                AnalyticsEventConstants.paramReminderHour: anchor.hour,
                AnalyticsEventConstants.paramReminderMinute: anchor.minute,
              },
            ),
      );

      // No setState: reminderEnabledProvider flipping to true hides the card.
    } catch (e, s) {
      // Previously swallowed: the user tapped the button, granted permission,
      // and got no reminder, no feedback and no event — invisible in both the
      // UI and analytics.
      AppLogger.e('END_SCREEN', 'Failed to enable daily reminders: $e', s);
      unawaited(
        ref
            .read(analyticsServiceProvider)
            .logEvent(
              name: AnalyticsEventConstants.endScreenReminderEnableFailed,
              parameters: _endScreenSourceParams,
            ),
      );
      if (mounted) {
        showSnackBar(context, AppLocalizations.of(context)!.anErrorOccurred);
      }
    }
  }
}
