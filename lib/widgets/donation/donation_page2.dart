/*This file is part of Medito App.

Medito App is free software: you can redistribute it and/or modify
it under the terms of the Affero GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

Medito App is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
Affero GNU General Public License for more details.

You should have received a copy of the Affero GNU General Public License
along with Medito App. If not, see <https://www.gnu.org/licenses/>.*/

import 'dart:async';

import 'package:Medito/tracking/tracking.dart';
import 'package:Medito/utils/colors.dart';
import 'package:Medito/utils/donate_utils.dart';
import 'package:Medito/utils/utils.dart';
import 'package:Medito/widgets/app_bar_widget.dart';
import 'package:Medito/widgets/donation/thank_you_page.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/painting.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/svg.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

class DonationWidgetPage2 extends StatefulWidget {
  DonationWidgetPage2(this.product);

  final ProductDetails product;

  @override
  _DonationWidgetPage2State createState() => _DonationWidgetPage2State();
}

class _DonationWidgetPage2State extends State<DonationWidgetPage2> {
  var _stayInTouchSelected = -1;
  bool _emailValid = false;
  final TextEditingController _emailController = TextEditingController();
  StreamSubscription<List<PurchaseDetails>> _subscription;

  static const SMALL_SIZE = 56.0;
  static const MEDIUM_SIZE = 56.0;

  @override
  void initState() {
    Tracking.changeScreenName(Tracking.DONATION_PAGE_2);
    _emailController.addListener(_handleEmail);
    getEmailAddress().then((value) => _emailController.text = value);

    final Stream purchaseUpdates =
        InAppPurchaseConnection.instance.purchaseUpdatedStream;
    _subscription = purchaseUpdates.listen((purchases) {
      _handlePurchaseUpdates(purchases);
    });

    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: MeditoAppBarWidget(
        titleWidget: SvgPicture.asset(
          'assets/images/medito.svg',
          height: 16,
        ),
        transparent: true,
      ),
      body: Padding(
        padding: const EdgeInsets.only(left: 16.0, right: 16.0, top: 16.0),
        child: CustomScrollView(
          physics: ClampingScrollPhysics(),
          slivers: [
            SliverFillRemaining(
                hasScrollBody: false, child: _buildColumn(context)),
          ],
        ),
      ),
    );
  }

  Column _buildColumn(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '3. What\'s your email address?',
          style: Theme.of(context).textTheme.headline2,
        ),
        Container(height: 12),
        _getEmailAddressBox(),
        Container(height: 32),
        Text('4. Can we stay in touch?',
            style: Theme.of(context).textTheme.headline2),
        Container(height: 12),
        Text(
            'We’ll send you updates, let you know how your donation is spent and if we need your support.',
            style: Theme.of(context)
                .textTheme
                .caption
                .copyWith(letterSpacing: 0.2)),
        Container(height: 12),
        _stayInTouchRow(),
        _stayInTouchSelected == 0 ? _begView() : Container(),
        Container(height: 32),
        _donateButton(),
        Expanded(child: Container(height: 32)),
        _explainRow(),
        Container(height: 16),
      ],
    );
  }

  Widget _stayInTouchRow() {
    return Row(
      mainAxisSize: MainAxisSize.max,
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        Expanded(
          flex: 1,
          child: SizedBox(
            height: SMALL_SIZE,
            child: TextButton(
              style: TextButton.styleFrom(
                backgroundColor: _stayInTouchSelected == 0
                    ? MeditoColors.peacefulBlue
                    : MeditoColors.moonlight,
              ),
              onPressed: _noClicked,
              child: Text(
                'No',
                style: Theme.of(context).textTheme.bodyText2.copyWith(
                    color: _stayInTouchSelected == 0
                        ? MeditoColors.almostBlack
                        : MeditoColors.walterWhite),
              ),
            ),
          ),
        ),
        Container(width: 8),
        Expanded(
          flex: 1,
          child: SizedBox(
            height: SMALL_SIZE,
            child: TextButton(
              style: TextButton.styleFrom(
                backgroundColor: _stayInTouchSelected == 1
                    ? MeditoColors.peacefulBlue
                    : MeditoColors.moonlight,
              ),
              onPressed: _yesClicked,
              child: Text(
                '💌 Yes',
                style: Theme.of(context).textTheme.bodyText2.copyWith(
                    color: _stayInTouchSelected == 1
                        ? MeditoColors.almostBlack
                        : MeditoColors.walterWhite),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _donateButton() {
    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: MEDIUM_SIZE,
      child: TextButton(
        style: TextButton.styleFrom(
            backgroundColor: MeditoColors.peacefulBlue.withAlpha(
                  (_emailValid && _stayInTouchSelected != -1) ? 255 : 172),),
              onPressed: () {
                if (_emailValid && _stayInTouchSelected != -1) _next();
              },
              child: Text(
                'Donate Now',
                style: Theme.of(context).textTheme.bodyText2.copyWith(
                    color: MeditoColors.moonlight, fontWeight: FontWeight.w500),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _begView() {
    return Column(
      children: [
        Container(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                '😔 We\'re sorry to hear that. Please hit YES if you are curious about what we do and how you can help in other ways! We don\'t email often.',
                textAlign: TextAlign.right,
                style: Theme.of(context).textTheme.caption,
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _noClicked() {
    SystemChannels.textInput.invokeMethod('TextInput.hide');
    setState(() {
      _stayInTouchSelected = 0;
    });
  }

  void _yesClicked() {
    SystemChannels.textInput.invokeMethod('TextInput.hide');
    setState(() {
      _stayInTouchSelected = 1;
    });
  }

  Widget _explainRow() {
    return Row(
      children: [
        SvgPicture.asset(
          'assets/images/walking_envelope.svg',
          height: 67,
          width: 67,
        ),
        Container(width: 16),
        Expanded(
          child: Text.rich(
            TextSpan(
              text:
                  'We really care about your privacy. We’ll never spam you or sell your data. ',
              style: Theme.of(context).textTheme.bodyText2,
              children: <TextSpan>[
                TextSpan(
                    text: 'Tap here to read our privacy policy.',
                    recognizer: TapGestureRecognizer()
                      ..onTap = () =>
                          launchUrl('https://meditofoundation.org/privacy'),
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

  Widget _getEmailAddressBox() {
    return Form(
      autovalidateMode: AutovalidateMode.onUserInteraction,
      child: Container(
        color: MeditoColors.moonlight,
        padding: const EdgeInsets.only(
            top: 8.0, bottom: 8.0, left: 16.0, right: 16.0),
        child: TextFormField(
          autofocus: _emailController.text.isEmpty,
          autofillHints: [AutofillHints.email],
          style: Theme.of(context).textTheme.headline2,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          autocorrect: false,
          keyboardType: TextInputType.emailAddress,
          controller: _emailController,
          cursorColor: MeditoColors.walterWhite,
          decoration: InputDecoration(
            hintText: 'Enter your email here',
            hintStyle: Theme.of(context)
                .textTheme
                .headline3
                .copyWith(color: MeditoColors.walterWhite.withAlpha(178)),
            suffixIcon: _emailController.text.isNotEmpty
                ? IconButton(
                    onPressed: () => _emailController.clear(),
                    icon: Icon(
                      Icons.clear,
                      color: MeditoColors.walterWhite,
                    ),
                  )
                : null,
            fillColor: Colors.white,
            border: InputBorder.none,
          ),
          validator: validateEmail,
        ),
      ),
    );
  }

  String validateEmail(String value) {
    Pattern pattern =
        '^[_a-z0-9-]+(.[a-z0-9-]+)@[a-z0-9-]+(.[a-z0-9-]+)*(.[a-z]{2,4})\$';
    var regex = RegExp(pattern);
    if (!regex.hasMatch(value) || value == null) {
      _emailValid = false;
      return 'Enter a valid email address';
    } else {
      _emailValid = true;
      return null;
    }
  }

  void _handleEmail() {
    validateEmail(_emailController.text);
    setState(() {});
  }

  void _next() {
    saveEmailAddress(_emailController.text);

    final purchaseParam = PurchaseParam(productDetails: widget.product);
    if (_isConsumable(widget.product)) {
      buyConsumable(purchaseParam);
    } else {
      buyNonConsumable(purchaseParam);
    }
// From here the purchase flow will be handled by the underlying storefront.
// Updates will be delivered to the `InAppPurchaseConnection.instance.purchaseUpdatedStream`.
  }

  void buyNonConsumable(PurchaseParam purchaseParam) {
    InAppPurchaseConnection.instance
        .buyNonConsumable(purchaseParam: purchaseParam);
  }

  void buyConsumable(PurchaseParam purchaseParam) {
    InAppPurchaseConnection.instance
        .buyConsumable(purchaseParam: purchaseParam);
  }

  bool _isConsumable(ProductDetails product) {
    return !product.id.contains('subscription');
  }

  void _handlePurchaseUpdates(List<PurchaseDetails> purchases) {
    purchases.retainWhere((element) => element.error == null);
    if (purchases.isNotEmpty) {
      savePurchases(purchases);
      _postToFirebase(purchases);

      Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ThankYouWidget(),
          ));
    }
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }

  void _postToFirebase(List<PurchaseDetails> purchases) {
    purchases.forEach((donation) {
      var amount = double.parse(donation.productID.split('_').last);
      Tracking.trackDonation(
          donation.billingClientPurchase.orderId.replaceAll('.', '_'),
          <String, dynamic>{
            'donor_id': donation.billingClientPurchase.purchaseToken,
            'donation_amount': amount,
            'donation_type': getDonationType(donation),
            'donation_currency': 'eur',
            'donation_fee': amount * .3,
            'donation_id': donation.billingClientPurchase.orderId,
            'donation_platform': 'app',
            'donation_timestamp': _getTimeStamp(donation),
            'donor_email': _emailController.text,
            'newsletter': _getNewsletterTrueOrFalse(),
            'pending': donation.status == PurchaseStatus.pending
          });
    });
  }

  String _getNewsletterTrueOrFalse() =>
      _stayInTouchSelected == 0 ? 'false' : 'true';

  int _getTimeStamp(PurchaseDetails donation) {
    var timeAsString = donation.billingClientPurchase.purchaseTime.toString();
    return int.parse(timeAsString.substring(0, timeAsString.length - 3));
  }

  dynamic getDonationType(PurchaseDetails donation) {
    if (donation.productID.contains('donation')) {
      return 1;
    } else {
      return 'Subscription update';
    }
  }
}
