import 'package:Medito/constants/constants.dart';
import 'package:Medito/models/models.dart';
import 'package:Medito/widgets/headers/medito_app_bar_small.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'widgets/donation_widget.dart';
import 'widgets/feedback_widget.dart';

class EndScreenView extends ConsumerStatefulWidget {
  final TrackModel trackModel;

  const EndScreenView({
    super.key,
    required this.trackModel,
  });

  @override
  ConsumerState<EndScreenView> createState() => _EndScreenViewState();
}

class _EndScreenViewState extends ConsumerState<EndScreenView> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: MeditoAppBarSmall(
        isTransparent: true,
        hasCloseButton: true,
      ),
      body: SingleChildScrollView(
        child: _buildCard(),
      ),
    );
  }

  Padding _buildCard() {
    var audio = widget.trackModel.audio.first;
    var files = audio.files.first;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: padding16),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: FeedbackWidget(
              trackId: widget.trackModel.id,
              audioFileDuration: files.duration,
              audioFileGuide: audio.guideName ?? '',
              audioFileId: files.id,
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: DonationWidget(),
          ),
        ],
      ),
    );
  }
}
