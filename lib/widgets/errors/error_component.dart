
import 'package:Medito/widgets/widgets.dart';
import 'package:Medito/constants/constants.dart';
import 'package:flutter/material.dart';

class MeditoErrorWidget extends StatelessWidget {
  const MeditoErrorWidget({
    Key? key,
    required this.onTap,
    required this.message,
    this.isLoading = false,
  }) : super(key: key);
  final void Function() onTap;
  final String message;
  final bool isLoading;
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ColorConstants.ebony,
      body: SizedBox(
        width: MediaQuery.of(context).size.width,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 15),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                message,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontSize: 16,
                      color: ColorConstants.walterWhite,
                      fontFamily: ClashDisplay,
                    ),
                textAlign: TextAlign.center,
              ),
              height16,
              LoadingButtonWidget(
                btnText: StringConstants.tryAgain,
                onPressed: onTap,
                isLoading: isLoading,
                bgColor: ColorConstants.walterWhite,
                textColor: ColorConstants.greyIsTheNewGrey,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
