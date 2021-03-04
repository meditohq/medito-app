import 'package:Medito/utils/colors.dart';
import 'package:Medito/utils/shared_preferences_utils.dart';
import 'package:Medito/utils/utils.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:in_app_review/in_app_review.dart';

class InAppReviewWidget extends StatelessWidget {


  InAppReviewWidget({@required this.thumbsdown});
  final VoidCallback thumbsdown;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.max,
      children: <Widget>[
        Expanded(
          child: SizedBox(
            height: 52,
            child: FlatButton(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12.0),
              ),
              onPressed: _rateUsPopUp,
              child: Icon(
                Icons.thumb_up,
                color: MeditoColors.almostBlack,
              ),
              color: MeditoColors.walterWhite,
            ),
          ),
        ),
        Container(
          width: 8,
        ),
        Expanded(
          child: SizedBox(
            height: 52,
            child: FlatButton(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12.0),
              ),
              onPressed: thumbsdown,
              child: Icon(
                Icons.thumb_down,
                color: MeditoColors.almostBlack,
              ),
              color: MeditoColors.moonlight,
            ),
          ),
        ),
      ],
    );
  }

  void _rateUsPopUp() {
    final inAppReview = InAppReview.instance;
    addCurrentDateToSF('UserAcceptedRating');
    var isAvailable = false;
    inAppReview.isAvailable().then((value) => isAvailable = value);
    if (isAvailable) {
      inAppReview.requestReview();
    }
    else {
      print('In App Review failed, Opening Store Listing instead');
      inAppReview.openStoreListing(appStoreId: '...', microsoftStoreId: '...'); //TODO: add these IDs
    }
  }

}
