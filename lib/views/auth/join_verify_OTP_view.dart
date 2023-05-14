import 'package:Medito/components/components.dart';
import 'package:Medito/constants/constants.dart';
import 'package:Medito/network/api_response.dart';
import 'package:Medito/providers/providers.dart';
import 'package:Medito/utils/validation_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pin_code_fields/pin_code_fields.dart';

class JoinVerifyOTPView extends ConsumerStatefulWidget {
  const JoinVerifyOTPView({super.key, required this.email});
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
        await auth.setUserEmailInSharedPref(widget.email);
        context.go(RouteConstants.joinWelcomePath);
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
                  child: _ResendCodeWidget(),
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

class _ResendCodeWidget extends StatelessWidget {
  const _ResendCodeWidget();

  @override
  Widget build(BuildContext context) {
    var textTheme = Theme.of(context).textTheme;

    return GestureDetector(
      onTap: () => {},
      child: Row(
        children: [
          Text(
            StringConstants.resendCode,
            style: textTheme.bodyMedium?.copyWith(
              color: ColorConstants.walterWhite,
              fontFamily: DmSans,
              height: 1.5,
              fontSize: 16,
              decoration: TextDecoration.underline,
            ),
          ),
          TweenAnimationBuilder<Duration>(
            duration: Duration(minutes: 3),
            tween: Tween(begin: Duration(minutes: 3), end: Duration.zero),
            onEnd: () {
              print('Timer ended');
            },
            builder: (BuildContext context, Duration value, Widget? child) {
              final minutes = value.inMinutes;
              final seconds = value.inSeconds % 60;

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Text(
                  '$minutes:$seconds',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                    fontSize: 30,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
