import 'package:medito/constants/constants.dart';
import 'package:medito/utils/utils.dart';
import 'package:medito/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

class ShareBtnWidget extends StatelessWidget {
  const ShareBtnWidget({
    super.key,
    required this.globalKey,
    this.shareText,
    this.onPressed,
  });

  final GlobalKey globalKey;
  final String? shareText;
  final void Function()? onPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: LoadingButtonWidget(
        onPressed: onPressed ?? () => _handleShare(context, globalKey),
        btnText: StringConstants.share,
        bgColor: ColorConstants.white,
        textColor: ColorConstants.onyx,
      ),
    );
  }

  Future<void> _handleShare(BuildContext context, GlobalKey key) async {
    try {
      var file = await capturePng(context, key);
      if (file != null) {
        await Share.shareXFiles(
          [XFile(file.path)],
          text: shareText,
        );
      } else {
        showSnackBar(context, StringConstants.someThingWentWrong);
      }
    } catch (e) {
      showSnackBar(context, StringConstants.someThingWentWrong);
    }
  }
}
