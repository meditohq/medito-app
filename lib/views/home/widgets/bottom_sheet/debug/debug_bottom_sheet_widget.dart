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
            error: (err, stack) => MeditoErrorWidget(
              message: err.toString(),
              onTap: () => ref.refresh(meProvider),
            ),
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(40.0),
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
          child: const Text(StringConstants.copy),
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
        info,
        style: labelMedium,
      ),
    );
  }

  void _handleCopy(BuildContext context, String deviceInfo) {
    var info =
        '${StringConstants.debugInfo}\n$deviceInfo\n${StringConstants.writeBelowThisLine}';

    Clipboard.setData(ClipboardData(text: info)).then((_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(StringConstants.debugInfoCopied),
          backgroundColor: ColorConstants.ebony,
        ),
      );
    });
  }
}