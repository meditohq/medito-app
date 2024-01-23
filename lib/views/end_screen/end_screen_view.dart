import 'package:Medito/constants/constants.dart';
import 'package:Medito/models/models.dart';
import 'package:Medito/widgets/headers/medito_app_bar_small.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'widgets/donation_widget.dart';
import 'widgets/feedback_widget.dart';

class EndScreenView extends ConsumerStatefulWidget {
  final List<EndScreenModel> endScreenModel;

  const EndScreenView({
    super.key,
    required this.endScreenModel,
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
        child: Column(
          children: [
            _buildCard(),
          ],
        ),
      ),
    );
  }

  Padding _buildCard() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: padding16),
      child: Column(
        children: widget.endScreenModel.map((e) {
          if (e.name == TypeConstants.donationAskCard) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: DonationWidget(
                donationModel: e.content,
              ),
            );
          }
          if (e.name == TypeConstants.feedbackCard) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: FeedbackWidget(
                feedbackModel: e.content,
              ),
            );
          }

          return SizedBox();
        }).toList(),
      ),
    );
  }

}
