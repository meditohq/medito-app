import 'package:Medito/constants/constants.dart';
import 'package:Medito/providers/providers.dart';
import 'package:Medito/utils/utils.dart';
import 'package:Medito/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../share_btn/share_btn_widget.dart';

class DebugBottomSheetWidget extends ConsumerWidget {
  const DebugBottomSheetWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var globalKey = GlobalKey();
    var deviceAppAndUserInfo = ref.watch(deviceAppAndUserInfoProvider);

    return Container(
      decoration: bottomSheetBoxDecoration,
      padding: EdgeInsets.only(bottom: getBottomPadding(context)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          height16,
          HandleBarWidget(),
          height16,
          deviceAppAndUserInfo.when(
            skipLoadingOnRefresh: false,
            data: (data) => _debugItemsList(
              context,
              globalKey,
              data,
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
    String info,
  ) {
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
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: SelectableText(
        '$info',
        style: labelMedium,
      ),
    );
  }

  void _handleShare(BuildContext context, String deviceInfo) async {
    var _info =
        '${StringConstants.debugInfo}\n$deviceInfo\n${StringConstants.writeBelowThisLine}';

    try {
      await launchEmailSubmission(
        StringConstants.supportEmail,
        subject: StringConstants.bugReport,
        body: _info,
      );
    } catch (e) {
      createSnackBar(
        e.toString(),
        context,
        color: ColorConstants.ebony,
      );
    }
  }
}
