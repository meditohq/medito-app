import 'package:Medito/utils/shared_preferences_utils.dart';
import 'package:Medito/utils/utils.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:in_app_review/in_app_review.dart';

class InAppReviewWidget extends StatelessWidget {
  BuildContext get context => context;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        child: Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: <Widget>[
              FloatingActionButton(
                onPressed: _rateUsPopUp,
                child: Icon(
                  Icons.thumb_up,
                  color: Colors.black12,
                ),
                backgroundColor: Colors.white,
              ),
              FloatingActionButton(
                onPressed: _thanksPopUp,
                child: Icon(
                  Icons.thumb_down,
                  color: Colors.black12,
                ),
                backgroundColor: Colors.white,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _rateUsPopUp() async {
    final inAppReview = InAppReview.instance;

    if (await inAppReview.isAvailable()) {
      await inAppReview.requestReview();
    }
  }

  void _thanksPopUp() {
    createSnackBarWithColor('Thanks for the rating!', context, Colors.black12);
    addCurrentDateToSF('UserDeclinedRating');
    Navigator.pop(context);
  }
}
