import 'package:medito/constants/constants.dart';
import 'package:medito/providers/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/events/events_provider.dart';

class FeedbackWidget extends ConsumerStatefulWidget {
  const FeedbackWidget({
    super.key,
    required this.trackId,
    required this.audioFileId,
    required this.audioFileDuration,
    required this.audioFileGuide,
  });

  final String trackId;
  final String audioFileId;
  final int audioFileDuration;
  final String audioFileGuide;

  @override
  ConsumerState<FeedbackWidget> createState() => _FeedbackWidgetState();
}

class _FeedbackWidgetState extends ConsumerState<FeedbackWidget> {
  bool isLoading = false;
  bool isFeedbackAdded = false;

  void _handleFeedbackPress(String feedback) async {
    setState(() {
      isLoading = true;
    });
    try {
      await ref.read(
        feedbackProvider(
          trackId: widget.trackId,
          feedbackEvent: {
            'rating': feedback,
            'audioFileDuration': widget.audioFileDuration.toString(),
            'audioFileGuide': widget.audioFileGuide.toString(),
            'audioFileId': widget.audioFileId,
          },
        ).future,
      );
      setState(() {
        isLoading = false;
        isFeedbackAdded = true;
      });
    } catch (e) {
      setState(() {
        isLoading = false;
        isFeedbackAdded = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    var bodyLarge = Theme.of(context).textTheme.bodyLarge;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: ColorConstants.onyx,
      ),
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: Column(
        children: [
          Text(
            StringConstants.howDoYouFeel,
            style: bodyLarge?.copyWith(fontFamily: SourceSerif, fontSize: 22),
            textAlign: TextAlign.center,
          ),
          height8,
          Text(
            StringConstants.yourFeedbackHelpsUs,
            style: bodyLarge?.copyWith(
              fontFamily: DmSans,
              fontSize: 16,
              color: ColorConstants.walterWhite,
            ),
            textAlign: TextAlign.center,
          ),
          height20,
          _buildFeedbackButton(),
        ],
      ),
    );
  }

  Widget _buildFeedbackButton() {
    var bodyLarge = Theme.of(context).textTheme.bodyLarge;

    if (isLoading) {
      return Padding(
        padding: const EdgeInsets.all(8),
        child: CircularProgressIndicator(),
      );
    } else if (isFeedbackAdded) {
      return Container(
        decoration: BoxDecoration(
          color: ColorConstants.ebony,
          borderRadius: BorderRadius.circular(14),
        ),
        padding: EdgeInsets.symmetric(horizontal: 30, vertical: padding16),
        margin: EdgeInsets.only(bottom: 4),
        child: Text(
          StringConstants.thanksForSharing,
          style: bodyLarge,
          textAlign: TextAlign.center,
        ),
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: InkWell(
            onTap: () => _handleFeedbackPress('🙁'),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: ColorConstants.ebony,
              ),
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Text(
                '🙁',
                style: TextStyle(fontSize: 40),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: InkWell(
            onTap: () => _handleFeedbackPress('😐'),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: ColorConstants.ebony,
              ),
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Text(
                '😐',
                style: TextStyle(fontSize: 40),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: InkWell(
            onTap: () => _handleFeedbackPress('😀'),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: ColorConstants.ebony,
              ),
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Text(
                '😀',
                style: TextStyle(fontSize: 40),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
