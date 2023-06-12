import 'package:Medito/constants/constants.dart';
import 'package:Medito/providers/providers.dart';
import 'package:Medito/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class DebugBottomSheetWidget extends ConsumerWidget {
  const DebugBottomSheetWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var userTokenModel = ref.read(authTokenProvider).asData?.value;
    var deviceInfo = ref.read(deviceInfoProvider).asData?.value;

    return DraggableSheetWidget(
      child: (scrollController) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            height16,
            HandleBarWidget(),
            height16,
            _debugRowItem(
              context,
              StringConstants.id,
              userTokenModel?.id,
            ),
            _debugRowItem(
              context,
              StringConstants.email,
              '',
            ),
            _debugRowItem(
              context,
              StringConstants.appVersion,
              '2.1.3',
            ),
            _debugRowItem(
              context,
              StringConstants.deviceModel,
              deviceInfo?.model,
            ),
            _debugRowItem(
              context,
              StringConstants.deviceOs,
              deviceInfo?.os,
            ),
            _debugRowItem(
              context,
              StringConstants.devicePlatform,
              deviceInfo?.platform,
            ),
          ],
        );
      },
    );
  }

  Padding _debugRowItem(BuildContext context, String title, String? text) {
    var labelMedium = Theme.of(context).textTheme.labelMedium;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 15),
      child: Row(
        children: [
          Text(
            '$title:',
            style: labelMedium,
          ),
          Text(
            text ?? '',
            style: labelMedium,
          ),
        ],
      ),
    );
  }
}
