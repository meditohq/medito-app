import 'package:Medito/constants/constants.dart';
import 'package:Medito/models/models.dart';
import 'package:Medito/providers/providers.dart';
import 'package:Medito/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../share_btn/share_btn_widget.dart';

class DebugBottomSheetWidget extends ConsumerWidget {
  const DebugBottomSheetWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var me = ref.watch(meProvider);
    var deviceInfo = ref.watch(deviceAndAppInfoProvider).asData?.value;
    var globalKey = GlobalKey();

    return DraggableSheetWidget(
      initialChildSize: 0.6,
      maxChildSize: 0.8,
      expand: false,
      child: (scrollController) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            height16,
            HandleBarWidget(),
            height16,
            me.when(
              skipLoadingOnRefresh: false,
              data: (data) => _debugItemsList(
                context,
                scrollController,
                globalKey,
                data,
                deviceInfo,
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
        );
      },
    );
  }

  Expanded _debugItemsList(
    BuildContext context,
    ScrollController scrollController,
    GlobalKey key,
    MeModel? me,
    DeviceAndAppInfoModel? deviceInfo,
  ) {
    return Expanded(
      child: SingleChildScrollView(
        controller: scrollController,
        child: Column(
          children: [
            RepaintBoundary(
              key: key,
              child: Container(
                color: ColorConstants.onyx,
                child: Column(
                  children: [
                    _debugRowItem(
                      context,
                      StringConstants.id,
                      me?.id,
                    ),
                    _debugRowItem(
                      context,
                      StringConstants.email,
                      me?.email,
                    ),
                    _debugRowItem(
                      context,
                      StringConstants.appVersion,
                      deviceInfo?.appVersion,
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
                    _debugRowItem(
                      context,
                      StringConstants.buidNumber,
                      deviceInfo?.buildNumber,
                    ),
                  ],
                ),
              ),
            ),
            ShareBtnWidget(
              globalKey: key,
            ),
          ],
        ),
      ),
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
