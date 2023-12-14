import 'dart:async';

import 'package:Medito/constants/constants.dart';
import 'package:Medito/models/models.dart';
import 'package:Medito/providers/providers.dart';
import 'package:Medito/routes/routes.dart';
import 'package:Medito/services/network/api_response.dart';
import 'package:Medito/services/notifications/notifications_service.dart';
import 'package:Medito/utils/validation_utils.dart';
import 'package:Medito/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pin_code_fields/pin_code_fields.dart';

import '../../utils/utils.dart';

class JoinVerifyOTPView extends ConsumerStatefulWidget {
  const JoinVerifyOTPView({
    super.key,
    required this.email,
    required this.fromScreen,
  });

  final Screen fromScreen;
  final String email;

  @override
  ConsumerState<JoinVerifyOTPView> createState() => _JoinVerifyOTPViewState();
}

class _JoinVerifyOTPViewState extends ConsumerState<JoinVerifyOTPView> {
  late AuthNotifier auth;
  final TextEditingController _otpTextEditingController =
      TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  void _handleVerify() async {
    if (_formKey.currentState!.validate()) {
      await auth.verifyOTP(widget.email, _otpTextEditingController.text);
      var status = auth.verifyOTPResponse.status;
      if (status == Status.COMPLETED) {
        await removeFirebaseToken();
        await requestGenerateFirebaseToken();
        // ignore: unused_result
        ref.invalidate(meProvider);
        ref.read(meProvider);
        var params = JoinRouteParamsModel(
          screen: widget.fromScreen,
          email: widget.email,
        );
        unawaited(context.push(
          RouteConstants.joinWelcomePath,
          extra: params,
        ));
      } else if (status == Status.ERROR) {
        showSnackBar(context, auth.verifyOTPResponse.message.toString());
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    auth = ref.watch(authProvider);
    var textTheme = Theme.of(context).textTheme;
    var isLoading = auth.verifyOTPResponse == ApiResponse.loading();

    return Scaffold(
      backgroundColor: ColorConstants.ebony,
      body: SafeArea(
        maintainBottomViewPadding: true,
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.only(
              top: 16, bottom: 0, left: 16, right: 16), // Updated padding
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        StringConstants.verifyYourAccount,
                        style: textTheme.headlineMedium?.copyWith(
                          color: ColorConstants.walterWhite,
                          fontFamily: DmSerif,
                          height: 1.2,
                          fontSize: 24,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(top: 16, bottom: 24),
                        child: Text(
                          StringConstants.verifyYourAccountInstruction
                              .replaceAll('replaceme', widget.email),
                          style: textTheme.bodyMedium?.copyWith(
                            color: ColorConstants.walterWhite,
                            fontFamily: DmSans,
                            height: 1.4,
                            fontSize: 16,
                          ),
                        ),
                      ),
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
                          fontFamily: DmSerif,
                          fontSize: 24,
                        ),
                        enableActiveFill: true,
                        autoFocus: true,
                        animationCurve: Curves.easeIn,
                        cursorColor: ColorConstants.walterWhite,
                        length: 6,
                        validator: ValidationUtils().validateOTP,
                        onChanged: (String _) => setState(() => {}),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: _ResendCodeWidget(
                          email: widget.email,
                        ),
                      ),
                      height16,
                    ],
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Container(
                      height: 48, // Set the height to 48 pixels
                      child: LoadingButtonWidget(
                        onPressed: () => context.pop(),
                        btnText: StringConstants.goBack,
                      ),
                    ),
                    width8,
                    Container(
                      height: 48, // Set the height to 48 pixels
                      child: LoadingButtonWidget(
                        onPressed: _otpTextEditingController.text != ''
                            ? _handleVerify
                            : null,
                        btnText: StringConstants.verify,
                        bgColor: ColorConstants.walterWhite,
                        textColor: ColorConstants.onyx,
                        isLoading: isLoading,
                      ),
                    ),
                  ],
                ),
                SizedBox(
                  height: getBottomPadding(context), // Added SizedBox
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ResendCodeWidget extends ConsumerWidget {
  const _ResendCodeWidget({required this.email});

  final String email;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var textTheme = Theme.of(context).textTheme;
    var auth = ref.watch(authProvider);

    void _handleResendOTP() async {
      await auth.sendOTP(email);
      auth.setCounter();
      var status = auth.sendOTPResponse.status;
      if (status == Status.COMPLETED) {
        showSnackBar(context, auth.sendOTPResponse.body.toString());
      } else if (status == Status.ERROR) {
        showSnackBar(context, auth.sendOTPResponse.message.toString());
        auth.setCounter();
      }
    }

    if (auth.sendOTPResponse.status == Status.LOADING) {
      return SizedBox(
        height: 16,
        width: 16,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: ColorConstants.walterWhite,
        ),
      );
    }

    return GestureDetector(
      onTap: () => {},
      child: Row(
        children: [
          GestureDetector(
            onTap: _handleResendOTP,
            child: Text(
              auth.counter
                  ? StringConstants.resendCodeIn
                  : StringConstants.resendCode,
              style: textTheme.bodyMedium?.copyWith(
                color: ColorConstants.walterWhite,
                fontFamily: DmSans,
                height: 1.5,
                fontSize: 14,
                fontWeight: FontWeight.w700,
                decoration: auth.counter
                    ? TextDecoration.none
                    : TextDecoration.underline,
              ),
            ),
          ),
          if (auth.counter) _counterAnimation(auth, textTheme),
        ],
      ),
    );
  }

  TweenAnimationBuilder<Duration> _counterAnimation(
    AuthNotifier auth,
    TextTheme textTheme,
  ) {
    return TweenAnimationBuilder<Duration>(
      duration: Duration(seconds: 45),
      tween: Tween(begin: Duration(seconds: 45), end: Duration.zero),
      onEnd: () {
        auth.setCounter();
      },
      builder: (BuildContext context, Duration value, Widget? child) {
        final minutes = value.inMinutes;
        final seconds = value.inSeconds % 60;

        return Text(
          '$minutes:$seconds',
          textAlign: TextAlign.center,
          style: textTheme.bodyMedium?.copyWith(
            color: ColorConstants.walterWhite,
            fontFamily: DmSans,
            height: 1.5,
            fontSize: 14,
          ),
        );
      },
    );
  }
}
