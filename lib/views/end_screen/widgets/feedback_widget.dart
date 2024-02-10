import 'package:Medito/constants/constants.dart';
import 'package:Medito/models/models.dart';
import 'package:Medito/providers/player/player_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/events/events_provider.dart';

class FeedbackWidget extends ConsumerStatefulWidget {
  const FeedbackWidget({super.key, required this.feedbackModel});

  final EndScreenContentModel feedbackModel;

  @override
  ConsumerState<FeedbackWidget> createState() => _FeedbackWidgetState();
}

class _FeedbackWidgetState extends ConsumerState<FeedbackWidget> {
  bool isLoading = false;
  bool isFeedbackAdded = false;

  void _handleFeedbackPress(String feedback) async {
    final audioProvider = ref.read(playerProvider);
    var trackId = audioProvider?.id ?? '';
    var audioFileId = audioProvider?.audio.first.files.first.id ?? '';

    setState(() {
      isLoading = true;
    });
    var payload = FeedbackTappedModel(
      trackId: trackId,
      audioFileId: audioFileId,
      emoji: feedback,
    );
    var event = EventsModel(
      name: EventTypes.trackFeedback,
      payload: payload.toJson(),
    );
    try {
      await ref.read(eventsProvider(event: event.toJson()).future);
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
            widget.feedbackModel.title ?? '',
            style: bodyLarge?.copyWith(fontFamily: SourceSerif, fontSize: 22),
            textAlign: TextAlign.center,
          ),
          height8,
          Text(
            widget.feedbackModel.text ?? '',
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
    var options = widget.feedbackModel.options;

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
    if (options != null) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: options
            .map((e) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: InkWell(
                    onTap: () => _handleFeedbackPress(e.value),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        color: ColorConstants.ebony,
                      ),
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      child: Text(
                        e.value,
                        style: TextStyle(fontSize: 40),
                      ),
                    ),
                  ),
                ))
            .toList(),
      );
    }

    return SizedBox();
  }
}
