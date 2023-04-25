import 'package:Medito/constants/constants.dart';
import 'package:Medito/utils/validation_utils.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:pin_code_fields/pin_code_fields.dart';

import 'widgets/auth_button_widget.dart';

class JoinVerifyOTPView extends StatefulWidget {
  const JoinVerifyOTPView({super.key});

  @override
  State<JoinVerifyOTPView> createState() => _JoinVerifyOTPViewState();
}

class _JoinVerifyOTPViewState extends State<JoinVerifyOTPView> {
  final TextEditingController _otpTextEditingController =
      TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  void _handleVerify() {
    if (_formKey.currentState!.validate()) {
      context.push(RouteConstants.joinWelcomePath);
    }
  }

  @override
  Widget build(BuildContext context) {
    var textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: ColorConstants.ebony,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 15),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  StringConstants.whatsYourEmail,
                  style: textTheme.headlineMedium?.copyWith(
                    color: ColorConstants.walterWhite,
                    fontFamily: ClashDisplay,
                    height: 2,
                    fontSize: 24,
                  ),
                ),
                height8,
                PinCodeTextField(
                  appContext: context,
                  controller: _otpTextEditingController,
                  backgroundColor: Colors.transparent,
                  keyboardType: TextInputType.number,
                  pinTheme: PinTheme(
                    fieldHeight: 56,
                    fieldWidth: 56,
                    selectedColor: ColorConstants.onyx,
                    borderRadius: BorderRadius.circular(5),
                    borderWidth: 0,
                    activeFillColor: ColorConstants.onyx,
                    inactiveFillColor: ColorConstants.onyx,
                    selectedFillColor: ColorConstants.onyx,
                    activeColor: ColorConstants.onyx,
                    inactiveColor: ColorConstants.onyx,
                    shape: PinCodeFieldShape.box,
                  ),
                  textStyle: textTheme.displayMedium?.copyWith(
                    color: ColorConstants.walterWhite,
                    fontFamily: ClashDisplay,
                    fontSize: 24,
                  ),
                  enableActiveFill: true,
                  autoFocus: true,
                  animationCurve: Curves.easeIn,
                  cursorColor: ColorConstants.walterWhite,
                  length: 6,
                  validator: ValidationUtils().validateOTP,
                  onChanged: (String _) {},
                ),
                Spacer(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    AuthButtonWidget(
                      onPressed: () => context.pop(),
                      btnText: StringConstants.goBack,
                    ),
                    width8,
                    AuthButtonWidget(
                      onPressed: _handleVerify,
                      btnText: StringConstants.verify,
                      bgColor: ColorConstants.walterWhite,
                      textColor: ColorConstants.greyIsTheNewGrey,
                    ),
                  ],
                ),
                height8,
              ],
            ),
          ),
        ),
      ),
    );
  }
}
