import 'package:flutter/material.dart';
import 'package:medito/constants/constants.dart';
import 'package:medito/services/analytics/firebase_analytics_service.dart';
import 'package:medito/l10n/app_localizations.dart';

class FeedbackWidget extends StatefulWidget {
  const FeedbackWidget({
    super.key,
  });

  @override
  State<FeedbackWidget> createState() => FeedbackWidgetState();
}

class FeedbackWidgetState extends State<FeedbackWidget> {
  bool _showThankYouMessage = false;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          spacing: 16,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              AppLocalizations.of(context)!.howDoYouFeel,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontFamily: teachers,
                    fontSize: 22,
                    fontWeight: FontWeight.normal,
                  ),
            ),
            _showThankYouMessage
                ? _buildThanksMessage()
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    spacing: 16,
                    children: [
                      Semantics(
                        button: true,
                        label:
                            AppLocalizations.of(context)!.thanksForSharingSad,
                        child: _buildEmotionButton(
                          context,
                          '☹️',
                          AppLocalizations.of(context)!.thanksForSharing,
                          _handleNegativeFeedback,
                        ),
                      ),
                      Semantics(
                        button: true,
                        label: AppLocalizations.of(context)!
                            .thanksForSharingNeutral,
                        child: _buildEmotionButton(
                          context,
                          '😐',
                          AppLocalizations.of(context)!.thanksForSharing,
                          _handleNeutralFeedback,
                        ),
                      ),
                      Semantics(
                        button: true,
                        label:
                            AppLocalizations.of(context)!.thanksForSharingHappy,
                        child: _buildEmotionButton(
                          context,
                          '😊',
                          AppLocalizations.of(context)!.thanksForSharing,
                          _handlePositiveFeedback,
                        ),
                      ),
                    ],
                  ),
          ],
        ),
      ),
    );
  }

  Widget _buildThanksMessage() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Text(
        AppLocalizations.of(context)!.thanksForSharing,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontSize: 18,
              fontWeight: FontWeight.w500,
            ),
      ),
    );
  }

  Future<void> _handlePositiveFeedback() async {
    setState(() {
      _showThankYouMessage = true;
    });

    await FirebaseAnalyticsService().logEvent(
      name: FirebaseAnalyticsService.eventPostMeditationFeedback,
      parameters: {
        'type': 'thumbs_up',
      },
    );
  }

  Future<void> _handleNeutralFeedback() async {
    setState(() {
      _showThankYouMessage = true;
    });

    await FirebaseAnalyticsService().logEvent(
      name: FirebaseAnalyticsService.eventPostMeditationFeedback,
      parameters: {
        'type': 'neutral',
      },
    );
  }

  Future<void> _handleNegativeFeedback() async {
    setState(() {
      _showThankYouMessage = true;
    });

    await FirebaseAnalyticsService().logEvent(
      name: FirebaseAnalyticsService.eventPostMeditationFeedback,
      parameters: {
        'feedback_type': 'thumbs_down',
      },
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
              : Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.06),
        ),
        child: Text(
          emoji,
          style: const TextStyle(fontSize: 32),
        ),
      ),
    );
  }
}
