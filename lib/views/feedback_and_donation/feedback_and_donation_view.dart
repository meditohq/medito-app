import 'package:Medito/constants/constants.dart';
import 'package:Medito/models/models.dart';
import 'package:Medito/views/main/app_bar_widget.dart';
import 'package:flutter/material.dart';
import 'widgets/donation_widget.dart';
import 'widgets/feedback_widget.dart';

class FeedbackAndDonationView extends StatelessWidget {
  final List<FeedbackAndDonationModel> feedbackAndDonationModel;
  const FeedbackAndDonationView({
    super.key,
    required this.feedbackAndDonationModel,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: MeditoAppBarWidget(
        isTransparent: true,
        hasCloseButton: true,
      ),
      body: Column(
        children: [
          height16,
          _buildCard(),
        ],
      ),
    );
  }

  Padding _buildCard() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: defaultPadding),
      child: Column(
        children: feedbackAndDonationModel.map((e) {
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
