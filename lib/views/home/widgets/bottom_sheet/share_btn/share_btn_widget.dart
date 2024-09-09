import 'package:medito/constants/constants.dart';
import 'package:medito/utils/utils.dart';
import 'package:medito/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

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
        final uri = Uri.file(file.path);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri);
        } else {
          showSnackBar(context, 'Could not open the file');
        }
      } else {
        print('File was null');
        showSnackBar(context, StringConstants.someThingWentWrong);
      }
    } catch (e) {
      showSnackBar(context, 'Failed to share: $e');
    }
  }
}
