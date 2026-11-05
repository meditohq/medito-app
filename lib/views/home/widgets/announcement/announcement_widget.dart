import 'package:medito/constants/constants.dart';
import 'package:medito/constants/strings/analytics_event_constants.dart';
import 'package:medito/models/home/announcement/announcement_model.dart';
import 'package:medito/providers/donation/announcement_donation_experiment.dart';
import 'package:medito/providers/shared_preference/shared_preference_provider.dart';
import 'package:medito/views/donation/supporter_donation_screen.dart';
import 'package:medito/views/home/home_styles.dart';
import 'package:medito/l10n/app_localizations.dart';
import 'package:medito/routes/routes.dart';
import 'package:medito/services/analytics/firebase_analytics_service.dart';
import 'package:medito/utils/launch_source_tracker.dart';
import 'package:medito/utils/utils.dart';
import 'package:medito/widgets/widgets.dart';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AnnouncementWidget extends ConsumerStatefulWidget {
  const AnnouncementWidget({
    super.key,
    required this.announcement,
    this.onPressedDismiss,
    this.onCtaPressed,
  });

  final AnnouncementModel announcement;
  final void Function()? onPressedDismiss;
  final VoidCallback? onCtaPressed;

  @override
  ConsumerState<AnnouncementWidget> createState() => _AnnouncementWidgetState();
}

/// Announcement ids already logged this app lifetime. Prevents a scroll /
/// rebuild / hot reload from inflating impressions; a cold restart or a
/// background→foreground round-trip legitimately gets a new impression.
final Set<String> _loggedImpressions = <String>{};

class _AnnouncementWidgetState extends ConsumerState<AnnouncementWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _sizeAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _logImpression();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    // Reverse curves are the mirrors of the forward ones: reversing through
    // an ease-out plays it backwards, so the dismiss would start slow and
    // speed up into the collapse. The mirrors decelerate on the way out too.
    _sizeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
      reverseCurve: Curves.easeIn,
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _handleDismiss() {
    FirebaseAnalyticsService().logEvent(
      name: AnalyticsEventConstants.announcementDismissed,
      parameters: _baseParams(),
    );
    _animationController.reverse().then((_) {
      widget.onPressedDismiss?.call();
    });
  }

  bool _isDonationCta() {
    final type = widget.announcement.ctaType;
    final path = widget.announcement.ctaPath;
    return type == 'donation' ||
        (type == TypeConstants.route && path == RouteConstants.donation);
  }

  Map<String, Object> _baseParams() {
    final params = <String, Object>{
      AnalyticsEventConstants.paramAnnouncementId: widget.announcement.id ?? '',
      AnalyticsEventConstants.paramAnnouncementCtaType:
          widget.announcement.ctaType ?? 'none',
      AnalyticsEventConstants.paramLaunchSource:
          LaunchSourceTracker.instance.current,
    };
    // Only tag the arm on donation surfaces, and only read it — assignment
    // happens at CTA tap so users who never see a donation card aren't
    // pulled into the experiment.
    if (_isDonationCta()) {
      final arm = AnnouncementDonationExperiment.peek(
        ref.read(sharedPreferencesProvider),
      );
      if (arm != null) {
        params[AnalyticsEventConstants.paramExperimentName] =
            AnnouncementDonationExperiment.experimentName;
        params[AnalyticsEventConstants.paramVariantId] = arm;
      }
    }
    return params;
  }

  void _logImpression() {
    final id = widget.announcement.id;
    if (id == null || id.isEmpty) return;
    if (!_loggedImpressions.add(id)) return;
    FirebaseAnalyticsService().logEvent(
      name: AnalyticsEventConstants.announcementImpression,
      parameters: _baseParams(),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.announcement.text == null) {
      return const SizedBox.shrink();
    }

    // The retheme uses one flat card surface everywhere; the announcement
    // follows it instead of the server-supplied colours, which read as a
    // heavy block against the rest of the home screen.
    return SizeTransition(
      sizeFactor: _sizeAnimation,
      alignment: AlignmentDirectional.topStart,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Padding(
          padding: const EdgeInsets.only(
            top: padding8,
            left: padding16,
            right: padding16,
            bottom: padding16,
          ),
          child: _GlassCard(
            child: Padding(
              padding: const EdgeInsets.only(
                left: padding20,
                right: padding20,
                bottom: padding12,
                top: padding20,
              ),
              child: Column(
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [_iconBadge(context), width16, _text(context)],
                  ),
                  height16,
                  _actionBtn(context),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Leading badge that marks the card as an announcement.
  Widget _iconBadge(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return Container(
      width: 36,
      height: 36,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: onSurface.withValues(alpha: 0.08),
      ),
      child: Icon(
        Icons.campaign_rounded,
        size: 20,
        color: onSurface.withValues(alpha: 0.85),
      ),
    );
  }

  Row _actionBtn(BuildContext context) {
    final theme = Theme.of(context);

    var actionWidgets = <Widget>[
      TextButton(
        onPressed: _handleDismiss,
        child: Text(
          AppLocalizations.of(context)!.dismiss,
          style: theme.textTheme.headlineMedium?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
      ),
      width4,
    ];

    if (widget.announcement.ctaPath != null) {
      // Themed ElevatedButton: accent fill with the accent's own foreground.
      actionWidgets.add(
        ElevatedButton(
          onPressed: widget.onCtaPressed ?? () => _handleCtaTitlePress(context),
          style: ElevatedButton.styleFrom(padding: const EdgeInsets.all(8)),
          child: Text(widget.announcement.ctaTitle ?? ''),
        ),
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: actionWidgets,
    );
  }

  Flexible _text(BuildContext context) {
    var markDownTheme = Theme.of(context).textTheme.bodyMedium?.copyWith(
      color: Theme.of(context).colorScheme.onSurface,
    );

    return Flexible(
      child: MarkdownWidget(
        body: widget.announcement.text ?? '',
        // Not selectable: TalkBack exposed the selectable text as a
        // long-clickable read-only field instead of plain text.
        selectable: false,
        textAlign: WrapAlignment.start,
        a: markDownTheme?.copyWith(
          decoration: TextDecoration.underline,
          fontWeight: FontWeight.w700,
        ),
        p: markDownTheme?.copyWith(fontWeight: FontWeight.w500),
      ),
    );
  }

  void _handleCtaTitlePress(BuildContext context) async {
    var path = widget.announcement.ctaPath;
    var type = widget.announcement.ctaType;
    final isDonation = _isDonationCta();

    // Assign the donation-CTA arm NOW (first tap, persisted) so the tap
    // event, the Stripe metadata, and the navigation decision all agree.
    final prefs = ref.read(sharedPreferencesProvider);
    if (isDonation) {
      AnnouncementDonationExperiment.resolveVariant(prefs);
    }

    FirebaseAnalyticsService().logEvent(
      name: AnalyticsEventConstants.announcementCtaTapped,
      parameters: _baseParams(),
    );

    if (isDonation) {
      final arm = AnnouncementDonationExperiment.peek(prefs);
      if (arm == AnnouncementDonationExperiment.variantNative) {
        await Navigator.of(context).push<bool>(
          MaterialPageRoute(
            builder: (_) => SupporterDonationScreen(
              campaignMetadata: AnnouncementDonationExperiment.paymentMetadata(
                prefs,
              ),
            ),
          ),
        );
        return;
      }
    }

    await handleNavigation(
      type,
      [path.toString().getIdFromPath(), path],
      context,
      ref: ref,
      sourceRouteName: isDonation
          ? FirebaseAnalyticsService.paywallSourceAnnouncement
          : null,
      donationCampaignMetadata: isDonation
          ? AnnouncementDonationExperiment.paymentMetadata(prefs)
          : const {},
    );
  }
}

/// Frosted, translucent card for the announcement, so the hero image shows
/// softly through it instead of a solid block.
class _GlassCard extends StatelessWidget {
  const _GlassCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final radius = BorderRadius.circular(kHomeCardRadius);
    return ClipRRect(
      borderRadius: radius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: theme.cardColor.withValues(alpha: 0.72),
            borderRadius: radius,
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.12)
                  : Colors.black.withValues(alpha: 0.08),
              width: 0.5,
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}
