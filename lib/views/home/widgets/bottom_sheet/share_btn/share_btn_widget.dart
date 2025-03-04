import 'package:medito/constants/constants.dart';
import 'package:medito/utils/utils.dart';
import 'package:flutter/material.dart';
import 'package:medito/widgets/snackbar_widget.dart';
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
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: onPressed ?? () => _handleShare(context, globalKey),
          style: ElevatedButton.styleFrom(
            backgroundColor: ColorConstants.white,
            foregroundColor: ColorConstants.onyx,
            padding: const EdgeInsets.symmetric(vertical: 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: Text(StringConstants.share),
        ),
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
