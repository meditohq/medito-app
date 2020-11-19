import 'package:Medito/utils/shared_preferences_utils.dart';
import 'package:Medito/utils/utils.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:in_app_review/in_app_review.dart';

class InAppReviewWidget extends StatelessWidget {
  BuildContext get context => this.context;

  @override
  Widget build(BuildContext context) {
    return new Scaffold(
      body: new Container(
        child: new Center(
          child: new Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: <Widget>[
              new FloatingActionButton(
                onPressed: rateUsPopUp,
                child: new Icon(
                  Icons.thumb_up,
                  color: Colors.black12,
                ),
                backgroundColor: Colors.white,
              ),
              new FloatingActionButton(
                onPressed: thanksPopUp,
                child: new Icon(
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

  void rateUsPopUp() async {
    final InAppReview inAppReview = InAppReview.instance;

    if (await inAppReview.isAvailable()) {
      inAppReview.requestReview();
    }
  }

  void thanksPopUp() {
    createSnackBarWithColor("Thanks for the rating", context, Colors.black12);
    addCurrentDateToSF("UserDeclinedRating");
    Navigator.pop(context);
  }
}
