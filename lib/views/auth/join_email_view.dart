import 'package:Medito/widgets/widgets.dart';
import 'package:Medito/constants/constants.dart';
import 'package:Medito/network/api_response.dart';
import 'package:Medito/providers/providers.dart';
import 'package:Medito/utils/validation_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class JoinEmailView extends ConsumerStatefulWidget {
  const JoinEmailView({super.key});

  @override
  ConsumerState<JoinEmailView> createState() => _JoinEmailViewState();
}

class _JoinEmailViewState extends ConsumerState<JoinEmailView> {
  late AuthNotifier auth;
  final TextEditingController _emailController =
      TextEditingController(text: '');
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  void _handleContinue() async {
    if (_formKey.currentState!.validate()) {
      var email = _emailController.text;
      await auth.sendOTP(email);
      auth.setCounter();
      var status = auth.sendOTPRes.status;
      if (status == Status.COMPLETED) {
        await context.push(
          RouteConstants.joinVerifyOTPPath,
          extra: {'email': email},
        );
      } else if (status == Status.ERROR) {
        showSnackBar(context, auth.sendOTPRes.message.toString());
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    var textTheme = Theme.of(context).textTheme;
    auth = ref.watch(authProvider);
    var isLoading = auth.sendOTPRes == ApiResponse.loading();

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
                  onChanged: (val) => setState(() => {}),
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
                      onPressed:
                          _emailController.text != '' ? _handleContinue : null,
                      btnText: StringConstants.continueTxt,
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
