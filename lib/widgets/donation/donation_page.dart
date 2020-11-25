import 'package:Medito/tracking/tracking.dart';
import 'package:Medito/utils/colors.dart';
import 'package:Medito/utils/utils.dart';
import 'package:Medito/widgets/app_bar_widget.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_svg/svg.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import 'donation_page2.dart';

class DonationWidget extends StatefulWidget {
  @override
  _DonationWidgetState createState() => _DonationWidgetState();
}

class _DonationWidgetState extends State<DonationWidget> {
  static const ONCE = 1;
  static const MONTHLY = 2;
  var _giveSelected = MONTHLY;
  var _amountSelect = 2;

  static const GIVE_SIZE = 56.0;
  static const NEXT_SIZE = 56.0;

  List<ProductDetails> donations;
  List<ProductDetails> subscriptions;

  @override
  void initState() {
    Tracking.changeScreenName(Tracking.DONATION_PAGE_1);

    _getDonationProducts();

    _getSubProducts();

    super.initState();
  }

  void _getSubProducts() {
    const Set<String> _subIds = {
      'subscription_5',
      'subscription_10',
      'subscription_15',
      'subscription_20',
      'subscription_30',
      'subscription_50'
    };

    InAppPurchaseConnection.instance.queryProductDetails(_subIds).then((value) {
      final ProductDetailsResponse response = value;
      if (response.notFoundIDs.isNotEmpty) {
        _getSubProducts();
      } else {
        subscriptions = response.productDetails;
        subscriptions.sort((a, b) => a.skuDetail.priceAmountMicros
            .compareTo(b.skuDetail.priceAmountMicros));

        setState(() {});
      }
    });
  }

  void _getDonationProducts() {
    const Set<String> _kIds = {
      'donation_5',
      'donation_10',
      'donation_15',
      'donation_20',
      'donation_30',
      'donation_50',
    };

    InAppPurchaseConnection.instance.queryProductDetails(_kIds).then((value) {
      final ProductDetailsResponse response = value;
      if (response.notFoundIDs.isNotEmpty) {
        _getDonationProducts();
      } else {
        donations = response.productDetails;
        donations.sort((a, b) => a.skuDetail.priceAmountMicros
            .compareTo(b.skuDetail.priceAmountMicros));

        setState(() {});
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: MeditoAppBarWidget(
        transparent: true,
        titleWidget: SvgPicture.asset(
          'assets/images/medito.svg',
          height: 16,
        ),
        hasCloseButton: true,
      ),
      body: subscriptions != null && subscriptions.isNotEmpty
          ? Padding(
            padding: const EdgeInsets.all(16.0),
            child: CustomScrollView(
                slivers: [
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('1. Donation type',
                            style: Theme.of(context).textTheme.headline2),
                        Container(height: 12),
                        _donationTypeRow(),
                        _giveSelected == ONCE ? _begView() : Container(),
                        Container(height: 32),
                        Text('2. Amount you want to give',
                            style: Theme.of(context).textTheme.headline2),
                        Container(height: 12),
                        _donationGrid(),
                        Container(height: 32),
                        _donateButton(),
                        Expanded(child: Container(height: 0)),
                        _explainRow(),
                      ],
                    ),
                  ),
                ],
              ),
          )
          : _loadingWidget(),
    );
  }

  Column _loadingWidget() {
    return Column(
            children: [
              Center(
                  child: SizedBox(
                      height: 32,
                      width: 32,
                      child: CircularProgressIndicator())),
            ],
          );
  }

  Widget _donationTypeRow() {
    return Row(
      mainAxisSize: MainAxisSize.max,
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        Expanded(
          flex: 1,
          child: SizedBox(
            height: GIVE_SIZE,
            child: FlatButton(
              color: _giveSelected == ONCE
                  ? MeditoColors.peacefulBlue
                  : MeditoColors.moonlight,
              child: Text(
                'Give Once',
                style: Theme.of(context).textTheme.bodyText2.copyWith(
                    fontWeight: FontWeight.w500,
                    color: _giveSelected == ONCE
                        ? MeditoColors.almostBlack
                        : MeditoColors.walterWhite),
              ),
              onPressed: _onceClicked,
            ),
          ),
        ),
        Container(width: 8),
        Expanded(
          flex: 1,
          child: SizedBox(
            height: GIVE_SIZE,
            child: FlatButton(
              color: _giveSelected == MONTHLY
                  ? MeditoColors.peacefulBlue
                  : MeditoColors.moonlight,
              child: Text(
                '♥️ Give Monthly',
                style: Theme.of(context).textTheme.bodyText2.copyWith(
                    fontWeight: FontWeight.w500,
                    color: _giveSelected == MONTHLY
                        ? MeditoColors.almostBlack
                        : MeditoColors.walterWhite),
              ),
              onPressed: _monthlyClicked,
            ),
          ),
        ),
      ],
    );
  }

  Widget _donationGrid() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            Expanded(
              child: SizedBox(
                height: GIVE_SIZE,
                child: FlatButton(
                  color: _amountSelect == 0
                      ? MeditoColors.peacefulBlue
                      : MeditoColors.moonlight,
                  child: Text(
                    getPrice(index: 0),
                    style: getAmountTextStyle(0),
                  ),
                  onPressed: () {
                    setState(() {
                      return _amountSelect = 0;
                    });
                  },
                ),
              ),
            ),
            Container(width: 8),
            Expanded(
              child: SizedBox(
                height: GIVE_SIZE,
                child: FlatButton(
                  color: _amountSelect == 1
                      ? MeditoColors.peacefulBlue
                      : MeditoColors.moonlight,
                  child: Text(
                    getPrice(index: 1),
                    style: getAmountTextStyle(1),
                  ),
                  onPressed: () {
                    setState(() {
                      return _amountSelect = 1;
                    });
                  },
                ),
              ),
            ),
            Container(width: 8),
            Expanded(
              child: SizedBox(
                height: GIVE_SIZE,
                child: FlatButton(
                  color: _amountSelect == 2
                      ? MeditoColors.peacefulBlue
                      : MeditoColors.moonlight,
                  child: Text(
                    getPrice(index: 2),
                    style: getAmountTextStyle(2),
                  ),
                  onPressed: () {
                    setState(() {
                      return _amountSelect = 2;
                    });
                  },
                ),
              ),
            ),
          ],
        ),
        Container(height: 8),
        Row(
          mainAxisSize: MainAxisSize.max,
          children: [
            Expanded(
              child: SizedBox(
                height: GIVE_SIZE,
                child: FlatButton(
                  color: _amountSelect == 3
                      ? MeditoColors.peacefulBlue
                      : MeditoColors.moonlight,
                  child: Text(
                    getPrice(index: 3),
                    style: getAmountTextStyle(3),
                  ),
                  onPressed: () {
                    setState(() {
                      return _amountSelect = 3;
                    });
                  },
                ),
              ),
            ),
            Container(width: 8),
            Expanded(
              child: SizedBox(
                height: GIVE_SIZE,
                child: FlatButton(
                  color: _amountSelect == 4
                      ? MeditoColors.peacefulBlue
                      : MeditoColors.moonlight,
                  child: Text(
                    getPrice(index: 4),
                    style: getAmountTextStyle(4),
                  ),
                  onPressed: () {
                    setState(() {
                      return _amountSelect = 4;
                    });
                  },
                ),
              ),
            ),
            Container(width: 8),
            Expanded(
              child: SizedBox(
                height: GIVE_SIZE,
                child: FlatButton(
                  color: _amountSelect == 5
                      ? MeditoColors.peacefulBlue
                      : MeditoColors.moonlight,
                  child: Text(
                    getPrice(index: 5),
                    style: getAmountTextStyle(5),
                  ),
                  onPressed: () {
                    setState(() {
                      return _amountSelect = 5;
                    });
                  },
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  TextStyle getAmountTextStyle(amountSelected) =>
      Theme.of(context).textTheme.bodyText2.copyWith(
          fontWeight: FontWeight.w500,
          color: _amountSelect == amountSelected
              ? MeditoColors.almostBlack
              : MeditoColors.walterWhite);

  Widget _donateButton() {
    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: NEXT_SIZE,
            child: FlatButton(
              color: MeditoColors.peacefulBlue,
              child: Text(
                'Next',
                style: Theme.of(context).textTheme.bodyText2.copyWith(
                      color: MeditoColors.moonlight,
                      fontWeight: FontWeight.w500,
                    ),
              ),
              onPressed: () => _openPage2(),
            ),
          ),
        ),
      ],
    );
  }

  void _openPage2() {
    var product = _giveSelected == 1
        ? donations[_amountSelect]
        : subscriptions[_amountSelect];

    Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => DonationWidgetPage2(product),
        ));
  }

  Widget _begView() {
    return Column(
      children: [
        Container(height: 8),
        Row(
          children: [
            Expanded(
              child: Text(
                'A monthly donation helps us reach even more people & plan ahead',
                textAlign: TextAlign.right,
                style: Theme.of(context).textTheme.headline3,
              ),
            ),
            Container(width: 16),
            SvgPicture.asset(
              'assets/images/up_arrow.svg',
            ),
          ],
        ),
      ],
    );
  }

  void _onceClicked() {
    setState(() {
      _giveSelected = ONCE;
    });
  }

  void _monthlyClicked() {
    setState(() {
      _giveSelected = MONTHLY;
    });
  }

  Widget _explainRow() {
    return Row(
      children: [
        SvgPicture.asset(
          'assets/images/small_hearts.svg',
          height: 67,
          width: 56,
        ),
        Container(width: 11),
        Expanded(
          child: Text.rich(
            TextSpan(
              text:
                  'Medito Foundation is a nonprofit registered in the UK & Netherlands. ',
              style: Theme.of(context).textTheme.headline3,
              children: <TextSpan>[
                TextSpan(
                    text: 'Tap here to learn more.',
                    recognizer: new TapGestureRecognizer()
                      ..onTap = () => launchUrl(
                          "https://meditofoundation.org/about/foundation"),
                    style: TextStyle(
                      decoration: TextDecoration.underline,
                    )),
              ],
            ),
          ),
        )
      ],
    );
  }

  String getPrice({int index}) {
    try {
      if (_giveSelected == ONCE) {
        return donations[index].skuDetail.price;
      } else {
        return subscriptions[index].skuDetail.price;
      }
    } catch (e) {
      return "oops!";
    }
  }
}
