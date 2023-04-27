import 'package:Medito/components/components.dart';
import 'package:Medito/constants/constants.dart';
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
      try {
        await auth.verifyOTP(widget.email, _otpTextEditingController.text);
        await context.push(RouteConstants.joinWelcomePath);
      } catch (e) {
        showSnackBar(context, e.toString());
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    auth = ref.watch(authProvider);
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
