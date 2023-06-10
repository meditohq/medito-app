import 'package:Medito/constants/constants.dart';
import 'package:Medito/widgets/widgets.dart';
import 'package:flutter/material.dart';

class DebugBottomSheetWidget extends StatelessWidget {
  const DebugBottomSheetWidget({super.key});

  @override
  Widget build(BuildContext context) {
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
              '1ddf1478-9beb-428d-97c1-f0085ff16768',
            ),
            _debugRowItem(
              context,
              StringConstants.email,
              'medito@medito.com',
            ),
            _debugRowItem(
              context,
              StringConstants.appVersion,
              '2.1.3',
            ),
            _debugRowItem(
              context,
              StringConstants.deviceModel,
              'xxxx',
            ),
          ],
        );
      },
    );
  }

  Padding _debugRowItem(BuildContext context, String title, String text) {
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
            text,
            style: labelMedium,
          ),
        ],
      ),
    );
  }
}
