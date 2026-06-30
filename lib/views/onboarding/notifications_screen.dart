// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:medito/constants/constants.dart';
import 'package:medito/l10n/app_localizations.dart';
import 'package:medito/providers/notification/reminder_provider.dart';
import 'package:medito/providers/settings/settings_providers.dart';
import 'package:medito/services/analytics/firebase_analytics_service.dart';
import 'package:medito/services/notifications/firebase_notifications_service.dart';
import 'package:medito/utils/permission_handler.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:medito/providers/shared_preference/shared_preference_provider.dart';
import 'package:medito/services/reminders/smart_reminders_service.dart';

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key, this.onNext, this.intentIndex});

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
  bool _notificationsGranted = false;
  bool _isProcessing = false;

  late final AnimationController _previewAnimation;

  /// Tagged on every event fired from this screen so analytics can
  /// distinguish the post-donation placement (re-introduced 26.6) from the
  /// pre-donation placement (removed 26.5.19).
  static const Map<String, Object> _placementParams = {
    'placement': 'post_donation',
  };

  @override
  void initState() {
    super.initState();
    _previewAnimation = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    Future.delayed(const Duration(milliseconds: 250), () {
      if (mounted) _previewAnimation.forward();
    });
    _checkNotificationPermission();
    FirebaseAnalyticsService().logEvent(
      name: FirebaseAnalyticsService.eventOnboardingNotificationsPreviewShown,
      parameters: _placementParams,
    );
  }

  @override
  void dispose() {
    _previewAnimation.dispose();
    super.dispose();
  }

  Future<void> _checkNotificationPermission() async {
    final status = await Permission.notification.status;
    if (mounted) {
      setState(() => _notificationsGranted = status.isGranted);
    }
  }

  Future<void> _handleNotificationsPermission() async {
    if (!mounted) return;

    setState(() => _isProcessing = true);
    final handler = ref.read(firebaseMessagingProvider);

    // Request notification permission if not already granted
    var status = await Permission.notification.status;
    if (!status.isGranted) {
      status = await Permission.notification.request();
    }

    if (!mounted) return;

    if (status.isGranted) {
      await handler.initialize(context, ref);

      // Log analytics event for permission granted in onboarding context
      await FirebaseAnalyticsService().logEvent(
        name: FirebaseAnalyticsService
            .eventOnboardingNotificationsPermissionGranted,
        parameters: _placementParams,
      );

      if (mounted) {
        setState(() {
          _notificationsGranted = true;
        });
      }

      // Automatically set up reminders and advance
      await _setupRemindersAndAdvance();
    } else {
      // Permission denied - log analytics event for onboarding context
      if (status.isDenied || status.isPermanentlyDenied) {
        await FirebaseAnalyticsService().logEvent(
          name: FirebaseAnalyticsService
              .eventOnboardingNotificationsPermissionDenied,
          parameters: {
            ..._placementParams,
            'permission_status': status.isPermanentlyDenied
                ? 'permanently_denied'
                : 'denied',
          },
        );
      }

      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
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

    await FirebaseAnalyticsService().logEvent(
      name: FirebaseAnalyticsService.eventOnboardingReminderSetTap,
      parameters: _placementParams,
    );

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
            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(32, 0, 32, 32),
              physics: const ClampingScrollPhysics(),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight - 48,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      children: [
                        Text(
                          _notificationsTitle(AppLocalizations.of(context)!),
                          style: Theme.of(context).textTheme.displayLarge
                              ?.copyWith(
                                fontSize: 24,
                                fontWeight: FontWeight.w600,
                              ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        Text(
                          _notificationsBody(AppLocalizations.of(context)!),
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(fontSize: 16, height: 1.5),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    _buildNotificationPreview(context),
                    const SizedBox(height: 24),
                    Column(
                      children: [
                        if (reminderTime != null)
                          _buildSmartRemindersOnButton()
                        else
                          _buildActionButton(
                            text: _notificationsGranted
                                ? AppLocalizations.of(
                                    context,
                                  )!.turnOnSmartReminders
                                : AppLocalizations.of(context)!.setReminderB,
                            onPressed: _isProcessing
                                ? null
                                : _handleNotificationsPermission,
                          ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: TextButton(
                            onPressed: () async {
                              // Log analytics event for skip tap
                              await FirebaseAnalyticsService().logEvent(
                                name: FirebaseAnalyticsService
                                    .eventOnboardingReminderSkipTap,
                                parameters: _placementParams,
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

  Widget _buildSmartRemindersOnButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: () async {
          await FirebaseAnalyticsService().logEvent(
            name: FirebaseAnalyticsService.eventOnboardingReminderConfirmTap,
            parameters: _placementParams,
          );
          _navigateNext();
        },
        child: Text(
          AppLocalizations.of(context)!.smartRemindersOn,
          style: const TextStyle(color: Colors.white),
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required String text,
    required VoidCallback? onPressed,
  }) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onPressed,
        child: Text(text, style: const TextStyle(color: Colors.white)),
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
