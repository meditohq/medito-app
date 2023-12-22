import 'package:Medito/constants/constants.dart';
import 'package:Medito/models/models.dart';
import 'package:Medito/providers/providers.dart';
import 'package:Medito/routes/routes.dart';
import 'package:Medito/utils/utils.dart';
import 'package:Medito/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class DonationWidget extends ConsumerWidget {
  final EndScreenContentModel donationModel;

  const DonationWidget({super.key, required this.donationModel});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var bodyLarge = Theme.of(context).textTheme.bodyLarge;
    var bgColor = parseColor(donationModel.colorBackground);

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: parseColor(donationModel.colorBackground),
      ),
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: Column(
        children: [
          Text(
            donationModel.title ?? '',
            style: bodyLarge?.copyWith(fontFamily: SourceSerif, fontSize: 22),
            textAlign: TextAlign.center,
          ),
          height8,
          Text(
            donationModel.text ?? '',
            style: bodyLarge?.copyWith(
              fontFamily: DmSans,
              fontSize: 16,
              color: parseColor(donationModel.colorText),
            ),
            textAlign: TextAlign.center,
          ),
          height20,
          Container(
            height: 48,
            width: MediaQuery.of(context).size.width,
            child: LoadingButtonWidget(
              onPressed: () => _handleDonatePress(ref),
              btnText: donationModel.ctaTitle ?? '',
              bgColor: ColorConstants.walterWhite,
              textColor: bgColor,
              fontSize: 18,
              fontWeight: FontWeight.w700,
              isLoading: false,
              borderRadius: 24,
            ),
          ),
        ],
      ),
    );
  }

  void _handleDonatePress(
    WidgetRef ref,
  ) {
    var payload = DonationTappedModel(
      origin: TypeConstants.donationAskCard,
      originId: donationModel.id.toString(),
    );
    var event = EventsModel(
      name: EventTypes.donationCtaTapped,
      payload: payload.toJson(),
    );
    ref.read(eventsProvider(event: event.toJson()).future);
    handleNavigation(donationModel.ctaType, [
      donationModel.ctaPath,
    ]);
  }
}
