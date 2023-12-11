import 'package:Medito/constants/constants.dart';
import 'package:Medito/utils/utils.dart';
import 'package:Medito/widgets/widgets.dart';
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
        bgColor: ColorConstants.walterWhite,
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
      showSnackBar(context, e.toString());
    }
  }
}
