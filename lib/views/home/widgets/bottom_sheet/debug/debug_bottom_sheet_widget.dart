import 'package:Medito/constants/constants.dart';
import 'package:Medito/models/models.dart';
import 'package:Medito/providers/providers.dart';
import 'package:Medito/utils/utils.dart';
import 'package:Medito/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../share_btn/share_btn_widget.dart';
import 'package:url_launcher/url_launcher.dart';

class DebugBottomSheetWidget extends ConsumerWidget {
  const DebugBottomSheetWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var me = ref.watch(meProvider);
    var deviceInfo = ref.watch(deviceAndAppInfoProvider);
    var globalKey = GlobalKey();

    return Container(
      decoration: bottomSheetBoxDecoration,
      padding: EdgeInsets.only(bottom: getBottomPadding(context)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          height16,
          HandleBarWidget(),
          height16,
          me.when(
            skipLoadingOnRefresh: false,
            data: (data) => _debugItemsList(
              context,
              globalKey,
              data,
              deviceInfo.value,
            ),
            error: (err, stack) => Expanded(
              child: MeditoErrorWidget(
                message: err.toString(),
                onTap: () => ref.refresh(meProvider),
              ),
            ),
            loading: () => Expanded(
              child: Center(
                child: CircularProgressIndicator(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Column _debugItemsList(
    BuildContext context,
    GlobalKey key,
    MeModel? me,
    DeviceAndAppInfoModel? deviceInfo,
  ) {
    var info = _formatString(me, deviceInfo);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        RepaintBoundary(
          key: key,
          child: _debugRowItem(
            context,
            info,
          ),
        ),
        ShareBtnWidget(
          globalKey: key,
          onPressed: () => _handleShare(context, info),
        ),
      ],
    );
  }

  Padding _debugRowItem(BuildContext context, String info) {
    var labelMedium = Theme.of(context).textTheme.labelMedium;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 15),
      child: SelectableText(
        '$info',
        style: labelMedium,
      ),
    );
  }

  void _handleShare(BuildContext context, String deviceInfo) async {
    var _info =
        '${StringConstants.debugInfo}\n$deviceInfo\n${StringConstants.writeBelowThisLine}';

    final params = Uri(
      scheme: 'mailto',
      path: StringConstants.supportEmail,
      query: 'body=$_info',
    );

    try {
      if (await canLaunchUrl(params)) {
        await launchUrl(params);
      }
    } catch (e) {
      createSnackBar(
        e.toString(),
        context,
        color: ColorConstants.darkBGColor,
      );
    }
  }

  String _formatString(
    MeModel? me,
    DeviceAndAppInfoModel? deviceInfo,
  ) {
    var id = StringConstants.id + ': ${me?.id ?? ''}';
    var email = StringConstants.email + ': ${me?.email ?? ''}';
    var appVersion =
        '${StringConstants.appVersion}: ${deviceInfo?.appVersion ?? ''}';
    var deviceModel =
        '${StringConstants.deviceModel}: ${deviceInfo?.model ?? ''}';
    var deviceOs = '${StringConstants.deviceOs}: ${deviceInfo?.os ?? ''}';
    var devicePlatform =
        '${StringConstants.devicePlatform}: ${deviceInfo?.platform ?? ''}';
    var buidNumber =
        '${StringConstants.buidNumber}: ${deviceInfo?.buildNumber ?? ''}';

    var formattedString =
        '$id\n$email\n$appVersion\n$deviceModel\n$deviceOs\n$devicePlatform\n$buidNumber';

    return formattedString;
  }
}
