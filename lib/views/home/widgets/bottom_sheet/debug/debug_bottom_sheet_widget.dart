import 'package:medito/constants/constants.dart';
import 'package:medito/providers/providers.dart';
import 'package:medito/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class DebugBottomSheetWidget extends ConsumerWidget {
  const DebugBottomSheetWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var deviceAppAndUserInfo = ref.watch(deviceAppAndUserInfoProvider);

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          deviceAppAndUserInfo.when(
            skipLoadingOnRefresh: false,
            data: (data) => _debugItemsList(
              context,
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
      String info,
      ) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _debugRowItem(
          context,
          info,
        ),
        ElevatedButton(
          child: Text(StringConstants.copy),
          onPressed: () => _handleCopy(context, info),
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

  void _handleCopy(BuildContext context, String deviceInfo) {
    var _info =
        '${StringConstants.debugInfo}\n$deviceInfo\n${StringConstants.writeBelowThisLine}';

    Clipboard.setData(ClipboardData(text: _info)).then((_) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(StringConstants.debugInfoCopied),
          backgroundColor: ColorConstants.ebony,
        ),
      );
    });
  }
}