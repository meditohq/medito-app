import 'package:flutter/material.dart';
import 'package:medito/constants/constants.dart';
import 'package:firebase_analytics/firebase_analytics.dart';

class FeedbackWidget extends StatefulWidget {
  const FeedbackWidget({super.key});

  @override
  State<FeedbackWidget> createState() => FeedbackWidgetState();
}

class FeedbackWidgetState extends State<FeedbackWidget> {
  bool _showThankYouMessage = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: ColorConstants.onyx,
      ),
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      child: Column(
        spacing: 16,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Text(
            StringConstants.howDoYouFeel,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: teachers,
              fontSize: 22,
              color: ColorConstants.white,
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
                      label: StringConstants.thanksForSharingHappy,
                      child: _buildEmotionButton(
                        context,
                        '😊',
                        StringConstants.thanksForSharing,
                        _handlePositiveFeedback,
                      ),
                    ),
                    Semantics(
                      button: true,
                      label: StringConstants.thanksForSharingNeutral,
                      child: _buildEmotionButton(
                        context,
                        '😐',
                        StringConstants.thanksForSharing,
                        _handleNeutralFeedback,
                      ),
                    ),
                    Semantics(
                      button: true,
                      label: StringConstants.thanksForSharingSad,
                      child: _buildEmotionButton(
                        context,
                        '☹️',
                        StringConstants.thanksForSharing,
                        _handleNegativeFeedback,
                      ),
                    ),
                  ],
                ),
        ],
      ),
    );
  }

  Widget _buildThanksMessage() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: const Text(
        StringConstants.thanksForSharing,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 18,
          color: ColorConstants.white,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Future<void> _handlePositiveFeedback() async {
    setState(() {
      _showThankYouMessage = true;
    });

    await FirebaseAnalytics.instance.logEvent(
      name: 'post_meditation_feedback',
      parameters: {
        'emotion': 'positive',
        'emoji': '😊',
      },
    );
  }

  Future<void> _handleNeutralFeedback() async {
    setState(() {
      _showThankYouMessage = true;
    });

    await FirebaseAnalytics.instance.logEvent(
      name: 'post_meditation_feedback',
      parameters: {
        'emotion': 'neutral',
        'emoji': '😐',
      },
    );
  }

  Future<void> _handleNegativeFeedback() async {
    setState(() {
      _showThankYouMessage = true;
    });

    await FirebaseAnalytics.instance.logEvent(
      name: 'post_meditation_feedback',
      parameters: {
        'emotion': 'negative',
        'emoji': '☹️',
      },
    );
  }

  Widget _buildEmotionButton(
    BuildContext context,
    String emoji,
    String feedbackMessage,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(2),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          shape: BoxShape.rectangle,
          borderRadius: BorderRadius.circular(8),
          color: ColorConstants.ebony,
        ),
        child: Text(
          emoji,
          style: const TextStyle(fontSize: 36),
        ),
      ),
    );
  }
}
