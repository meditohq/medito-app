import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medito/constants/constants.dart';
import 'package:medito/constants/strings/analytics_event_constants.dart';
import 'package:medito/providers/review_service_provider.dart';
import 'package:medito/services/analytics/firebase_analytics_service.dart';
import 'package:medito/l10n/app_localizations.dart';

import 'end_screen_card.dart';

const _reviewAskSourceParams = <String, Object>{
  AnalyticsEventConstants.paramSource: AnalyticsEventConstants.sourceEndScreen,
};

class FeedbackWidget extends ConsumerStatefulWidget {
  const FeedbackWidget({
    super.key,
    this.suppressRatingAsk,
    this.initiallyShowRatingAsk = false,
  });

  /// Read at 😊-tap time: true when another ask already got a response on
  /// this end screen (a donate tap), so the rating ask waits for another day.
  final ValueGetter<bool>? suppressRatingAsk;

  /// Opens straight on the rating ask; for widget previews only.
  final bool initiallyShowRatingAsk;

  @override
  ConsumerState<FeedbackWidget> createState() => FeedbackWidgetState();
}

class FeedbackWidgetState extends ConsumerState<FeedbackWidget> {
  bool _showThankYouMessage = false;

  /// The one-time rating ask is showing in place of the thank-you line.
  late bool _showRatingAsk = widget.initiallyShowRatingAsk;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: AnimatedSize(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        alignment: Alignment.topCenter,
        child: _showRatingAsk ? _buildRatingAsk() : _buildFeedback(),
      ),
    );
  }

  Widget _buildFeedback() {
    return EndScreenCard(
      title: AppLocalizations.of(context)!.howDoYouFeel,
      child: _showThankYouMessage
          ? _buildThanksMessage()
          : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              spacing: 16,
              children: [
                Semantics(
                  button: true,
                  label: AppLocalizations.of(context)!.thanksForSharingSad,
                  child: _buildEmotionButton(
                    context,
                    '☹️',
                    AppLocalizations.of(context)!.thanksForSharing,
                    _handleNegativeFeedback,
                  ),
                ),
                Semantics(
                  button: true,
                  label: AppLocalizations.of(context)!.thanksForSharingNeutral,
                  child: _buildEmotionButton(
                    context,
                    '😐',
                    AppLocalizations.of(context)!.thanksForSharing,
                    _handleNeutralFeedback,
                  ),
                ),
                Semantics(
                  button: true,
                  label: AppLocalizations.of(context)!.thanksForSharingHappy,
                  child: _buildEmotionButton(
                    context,
                    '😊',
                    AppLocalizations.of(context)!.thanksForSharing,
                    _handlePositiveFeedback,
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildRatingAsk() {
    final l10n = AppLocalizations.of(context)!;
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return EndScreenCard(
      title: l10n.ratingAskTitle,
      body: l10n.ratingAskBody,
      bottomPadding: 8,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ElevatedButton(
            onPressed: _handleRate,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            child: Text(
              l10n.ratingAskCta,
              textAlign: TextAlign.center,
              style: EndScreenCard.buttonStyle(
                context,
                color: context.onBrandAccent,
              ),
            ),
          ),
          TextButton(
            onPressed: _handleNotNow,
            child: Text(
              l10n.notNow,
              style: EndScreenCard.secondaryStyle(
                context,
                color: onSurface.withValues(alpha: 0.7),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _handleRate() {
    setState(() => _showRatingAsk = false);
    unawaited(
      FirebaseAnalyticsService().logEvent(
        name: AnalyticsEventConstants.reviewPromptRateTap,
        parameters: _reviewAskSourceParams,
      ),
    );
    unawaited(ref.read(reviewServiceProvider).openStore());
  }

  void _handleNotNow() {
    setState(() => _showRatingAsk = false);
    unawaited(
      FirebaseAnalyticsService().logEvent(
        name: AnalyticsEventConstants.reviewPromptNotNowTap,
        parameters: _reviewAskSourceParams,
      ),
    );
  }

  Widget _buildThanksMessage() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Text(
        AppLocalizations.of(context)!.thanksForSharing,
        textAlign: TextAlign.center,
        style: EndScreenCard.bodyStyle(context),
      ),
    );
  }

  Future<void> _handlePositiveFeedback() async {
    setState(() {
      _showThankYouMessage = true;
    });

    unawaited(
      FirebaseAnalyticsService().logEvent(
        name: FirebaseAnalyticsService.eventPostMeditationFeedback,
        parameters: {'type': 'thumbs_up'},
      ),
    );

    final reviewService = ref.read(reviewServiceProvider);
    final showAsk = await reviewService.onHappyFeedback(
      suppress: widget.suppressRatingAsk?.call() ?? false,
    );
    if (!showAsk || !mounted) return;

    // Let the thank-you register for a beat before the card grows into the ask.
    await Future.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;
    await reviewService.markShown();
    if (!mounted) return;
    setState(() => _showRatingAsk = true);
    unawaited(
      FirebaseAnalyticsService().logEvent(
        name: AnalyticsEventConstants.reviewPromptShown,
        parameters: _reviewAskSourceParams,
      ),
    );
  }

  Future<void> _handleNeutralFeedback() async {
    setState(() {
      _showThankYouMessage = true;
    });

    await FirebaseAnalyticsService().logEvent(
      name: FirebaseAnalyticsService.eventPostMeditationFeedback,
      parameters: {'type': 'neutral'},
    );
  }

  Future<void> _handleNegativeFeedback() async {
    setState(() {
      _showThankYouMessage = true;
    });

    await FirebaseAnalyticsService().logEvent(
      name: FirebaseAnalyticsService.eventPostMeditationFeedback,
      parameters: {'type': 'thumbs_down'},
    );
  }

  Widget _buildEmotionButton(
    BuildContext context,
    String emoji,
    String feedbackMessage,
    VoidCallback onTap,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          shape: BoxShape.rectangle,
          borderRadius: BorderRadius.circular(12),
          color: isDark
              ? ColorConstants.ebony
              : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.06),
        ),
        // The Semantics label around this button names the feeling; the
        // emoji itself would be read again after it.
        child: ExcludeSemantics(
          child: Text(emoji, style: const TextStyle(fontSize: 32)),
        ),
      ),
    );
  }
}
