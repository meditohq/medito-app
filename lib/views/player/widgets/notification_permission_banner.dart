import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medito/constants/strings/analytics_event_constants.dart';
import 'package:medito/constants/styles/widget_styles.dart';
import 'package:medito/l10n/app_localizations.dart';
import 'package:medito/providers/providers.dart';
import 'package:permission_handler/permission_handler.dart';

/// A visually quiet, dismissable strip shown at the top of the player on
/// Android when POST_NOTIFICATIONS is denied. Tapping "Enable" prompts the
/// OS (or deep-links to system settings when permanently denied). Hidden on
/// iOS and once permission is granted.
class NotificationPermissionBanner extends ConsumerStatefulWidget {
  const NotificationPermissionBanner({super.key});

  @override
  ConsumerState<NotificationPermissionBanner> createState() =>
      _NotificationPermissionBannerState();
}

class _NotificationPermissionBannerState
    extends ConsumerState<NotificationPermissionBanner>
    with WidgetsBindingObserver {
  PermissionStatus? _status;
  bool _dismissedThisSession = false;
  bool _shownLogged = false;

  @override
  void initState() {
    super.initState();
    if (Platform.isAndroid) {
      WidgetsBinding.instance.addObserver(this);
      unawaited(_refreshStatus());
    }
  }

  @override
  void dispose() {
    if (Platform.isAndroid) {
      WidgetsBinding.instance.removeObserver(this);
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_refreshStatus());
    }
  }

  Future<void> _refreshStatus() async {
    final status = await Permission.notification.status;
    if (!mounted) return;
    setState(() => _status = status);
  }

  bool get _shouldShow {
    if (!Platform.isAndroid) return false;
    if (_dismissedThisSession) return false;
    final s = _status;
    if (s == null) return false;
    return s.isDenied || s.isPermanentlyDenied;
  }

  void _logShownIfNeeded() {
    if (_shownLogged || !_shouldShow) return;
    _shownLogged = true;
    unawaited(
      ref.read(analyticsServiceProvider).logEvent(
            name: AnalyticsEventConstants.mediaPermissionBannerShown,
          ),
    );
  }

  Future<void> _onEnableTapped() async {
    unawaited(
      ref.read(analyticsServiceProvider).logEvent(
            name: AnalyticsEventConstants.mediaPermissionBannerEnableTapped,
          ),
    );

    final current = _status ?? await Permission.notification.status;
    if (!mounted) return;

    if (current.isPermanentlyDenied) {
      unawaited(
        ref.read(analyticsServiceProvider).logEvent(
              name: AnalyticsEventConstants.mediaPermissionSettingsOpened,
              parameters: {
                AnalyticsEventConstants.paramSource:
                    AnalyticsEventConstants.sourcePlayerBanner,
              },
            ),
      );
      await openAppSettings();
      // Status will be re-checked on lifecycle resume.
      return;
    }

    final newStatus = await Permission.notification.request();
    if (!mounted) return;

    final event = newStatus.isGranted
        ? AnalyticsEventConstants.mediaPermissionGranted
        : AnalyticsEventConstants.mediaPermissionDenied;
    unawaited(
      ref.read(analyticsServiceProvider).logEvent(
            name: event,
            parameters: {
              AnalyticsEventConstants.paramSource:
                  AnalyticsEventConstants.sourcePlayerBanner,
            },
          ),
    );

    setState(() => _status = newStatus);
  }

  void _onDismiss() {
    unawaited(
      ref.read(analyticsServiceProvider).logEvent(
            name: AnalyticsEventConstants.mediaPermissionBannerDismissed,
          ),
    );
    setState(() => _dismissedThisSession = true);
  }

  @override
  Widget build(BuildContext context) {
    final visible = _shouldShow;
    if (visible) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _logShownIfNeeded();
      });
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeIn,
      transitionBuilder: (child, animation) {
        final slide = Tween<Offset>(
          begin: const Offset(0, -0.5),
          end: Offset.zero,
        ).animate(animation);
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(position: slide, child: child),
        );
      },
      child: visible
          ? _BannerContent(
              key: const ValueKey('banner'),
              onEnable: _onEnableTapped,
              onDismiss: _onDismiss,
            )
          : const SizedBox.shrink(key: ValueKey('empty')),
    );
  }
}

class _BannerContent extends StatelessWidget {
  final VoidCallback onEnable;
  final VoidCallback onDismiss;

  const _BannerContent({
    super.key,
    required this.onEnable,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final mutedColor = theme.colorScheme.onSurface.withValues(alpha: 0.75);

    return Material(
      color: Colors.transparent,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(padding16, padding8, padding8, padding8),
        child: Row(
          children: [
            Icon(
              Icons.notifications_none_rounded,
              size: 18,
              color: mutedColor,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                l10n.playerNotificationBannerText,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontFamily: teachers,
                  fontSize: 13,
                  height: 1.3,
                  color: mutedColor,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            TextButton(
              onPressed: onEnable,
              style: TextButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                minimumSize: const Size(0, 32),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                foregroundColor: theme.colorScheme.onSurface,
              ),
              child: Text(
                l10n.playerNotificationBannerEnable,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontFamily: teachers,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ),
            IconButton(
              onPressed: onDismiss,
              tooltip: l10n.playerNotificationBannerDismiss,
              splashRadius: 18,
              iconSize: 18,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(
                minWidth: 32,
                minHeight: 32,
              ),
              color: mutedColor,
              icon: const Icon(Icons.close_rounded),
            ),
          ],
        ),
      ),
    );
  }
}
