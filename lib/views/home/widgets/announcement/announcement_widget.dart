import 'package:medito/constants/constants.dart';
import 'package:medito/models/home/announcement/announcement_model.dart';
import 'package:medito/views/home/home_styles.dart';
import 'package:medito/l10n/app_localizations.dart';
import 'package:medito/routes/routes.dart';
import 'package:medito/services/analytics/firebase_analytics_service.dart';
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
  });

  final AnnouncementModel announcement;
  final void Function()? onPressedDismiss;

  @override
  ConsumerState<AnnouncementWidget> createState() => _AnnouncementWidgetState();
}

class _AnnouncementWidgetState extends ConsumerState<AnnouncementWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _sizeAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _sizeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _handleDismiss() {
    _animationController.reverse().then((_) {
      widget.onPressedDismiss?.call();
    });
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
          onPressed: () => _handleCtaTitlePress(context),
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
        selectable: true,
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
    var isDonation =
        type == 'donation' ||
        (type == TypeConstants.route && path == RouteConstants.donation);
    await handleNavigation(
      type,
      [path.toString().getIdFromPath(), path],
      context,
      ref: ref,
      sourceRouteName: isDonation
          ? FirebaseAnalyticsService.paywallSourceAnnouncement
          : null,
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
