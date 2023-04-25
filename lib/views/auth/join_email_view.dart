import 'package:Medito/components/components.dart';
import 'package:Medito/constants/constants.dart';
import 'package:Medito/utils/validation_utils.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class JoinEmailView extends StatefulWidget {
  const JoinEmailView({super.key});

  @override
  State<JoinEmailView> createState() => _JoinEmailViewState();
}

class _JoinEmailViewState extends State<JoinEmailView> {
  final TextEditingController _emailController =
      TextEditingController(text: 'osama.asif20@gmail.com');
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  void _handleContinue() {
    if (_formKey.currentState!.validate()) {
      context.push(RouteConstants.joinVerifyOTPPath);
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
                TextFormField(
                  controller: _emailController,
                  cursorColor: ColorConstants.walterWhite,
                  cursorHeight: 22,
                  cursorWidth: 1,
                  style: textTheme.bodyMedium?.copyWith(
                    color: ColorConstants.walterWhite,
                    fontFamily: DmSans,
                    fontSize: 16,
                  ),
                  validator: ValidationUtils().validateEmail,
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
                      onPressed: _handleContinue,
                      btnText: StringConstants.continueTxt,
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
