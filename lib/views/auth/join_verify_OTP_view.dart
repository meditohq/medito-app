import 'dart:async';

import 'package:Medito/models/models.dart';
import 'package:Medito/routes/routes.dart';
import 'package:Medito/services/notifications/notifications_service.dart';
import 'package:Medito/widgets/widgets.dart';
import 'package:Medito/constants/constants.dart';
import 'package:Medito/network/api_response.dart';
import 'package:Medito/providers/providers.dart';
import 'package:Medito/utils/validation_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pin_code_fields/pin_code_fields.dart';

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
      var status = auth.verifyOTPRes.status;
      if (status == Status.COMPLETED) {
        await removeFirebaseToken();
        await requestGenerateFirebaseToken();
        var params = JoinRouteParamsModel(
            screen: widget.fromScreen, email: widget.email);
        unawaited(context.push(
          RouteConstants.joinWelcomePath,
          extra: params,
        ));
      } else if (status == Status.ERROR) {
        showSnackBar(context, auth.verifyOTPRes.message.toString());
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    auth = ref.watch(authProvider);
    var textTheme = Theme.of(context).textTheme;
    var isLoading = auth.verifyOTPRes == ApiResponse.loading();

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
                  StringConstants.verifyYourAccount,
                  style: textTheme.headlineMedium?.copyWith(
                    color: ColorConstants.walterWhite,
                    fontFamily: ClashDisplay,
                    height: 2,
                    fontSize: 24,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Text(
                    StringConstants.verifyYourAccountInstruction
                        .replaceAll('replaceme', widget.email),
                    style: textTheme.bodyMedium?.copyWith(
                      color: ColorConstants.walterWhite,
                      fontFamily: DmSans,
                      height: 1.5,
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
                    fontFamily: ClashDisplay,
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
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: _ResendCodeWidget(
                    email: widget.email,
                  ),
                ),
                Spacer(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    LoadingButtonWidget(
                      onPressed: () => context.pop(),
                      btnText: StringConstants.goBack,
                    ),
                    width8,
                    LoadingButtonWidget(
                      onPressed: _otpTextEditingController.text != ''
                          ? _handleVerify
                          : null,
                      btnText: StringConstants.verify,
                      bgColor: ColorConstants.walterWhite,
                      textColor: ColorConstants.greyIsTheNewGrey,
                      isLoading: isLoading,
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
      var status = auth.sendOTPRes.status;
      if (status == Status.COMPLETED) {
        showSnackBar(context, auth.sendOTPRes.body.toString());
      } else if (status == Status.ERROR) {
        showSnackBar(context, auth.sendOTPRes.message.toString());
        auth.setCounter();
      }
    }

    if (auth.sendOTPRes.status == Status.LOADING) {
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

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Text(
            '$minutes:$seconds',
            textAlign: TextAlign.center,
            style: textTheme.bodyMedium?.copyWith(
              color: ColorConstants.walterWhite,
              fontFamily: DmSans,
              height: 1.5,
              fontSize: 14,
            ),
          ),
        );
      },
    );
  }
}
