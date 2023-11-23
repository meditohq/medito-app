import 'package:Medito/constants/styles/widget_styles.dart';
import 'package:Medito/models/models.dart';
import 'package:Medito/views/feedback_and_donation/widgets/donation_widget.dart';
import 'package:Medito/views/main/app_bar_widget.dart';
import 'package:flutter/material.dart';
import 'widgets/feedback_widget.dart';

class FeedbackAndDonationView extends StatelessWidget {
  final EndScreenModel endScreenModel;
  const FeedbackAndDonationView({super.key, required this.endScreenModel});

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
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: defaultPadding,
            ),
            child: FeedbackWidget(
              feedbackModel: endScreenModel.feedbackCard,
            ),
          ),
          height20,
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: defaultPadding,
            ),
            child: DonationWidget(
              donationModel: endScreenModel.donationAskCard,
            ),
          ),
        ],
      ),
    );
  }
}
