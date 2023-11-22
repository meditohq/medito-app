import 'package:Medito/constants/constants.dart';
import 'package:Medito/models/models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class FeedbackWidget extends ConsumerStatefulWidget {
  const FeedbackWidget({super.key, required this.feedbackModel});

  final FeedbackModel feedbackModel;

  @override
  ConsumerState<FeedbackWidget> createState() => _FeedbackWidgetState();
}

class _FeedbackWidgetState extends ConsumerState<FeedbackWidget> {
  @override
  Widget build(BuildContext context) {
    var bodyLarge = Theme.of(context).textTheme.bodyLarge;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: ColorConstants.onyx,
      ),
      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      child: Column(
        children: [
          Text(
            widget.feedbackModel.title,
            style: bodyLarge?.copyWith(fontFamily: DmSerif, fontSize: 24),
            textAlign: TextAlign.center,
          ),
          height8,
          Text(
            widget.feedbackModel.text,
            style: bodyLarge?.copyWith(
              fontFamily: DmSans,
              fontSize: 16,
              color: ColorConstants.walterWhite,
            ),
            textAlign: TextAlign.center,
          ),
          height20,
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: widget.feedbackModel.options
                .map((e) => _buildFeedbackButton(e.value))
                .toList(),
          ),
        ],
      ),
    );
  }

  Padding _buildFeedbackButton(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: ColorConstants.ebony,
        ),
        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Text(
          text,
          style: TextStyle(fontSize: 40),
        ),
      ),
    );
  }
}
