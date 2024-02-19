import 'package:Medito/constants/constants.dart';
import 'package:Medito/providers/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../bottom_sheet/stats/stats_bottom_sheet_widget.dart';

void _onTapTile(BuildContext context, WidgetRef ref) {
  ref.invalidate(remoteStatsProvider);
  ref.read(remoteStatsProvider);
  showModalBottomSheet<void>(
    context: context,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.only(
        topLeft: Radius.circular(14.0),
        topRight: Radius.circular(14.0),
      ),
    ),
    isScrollControlled: true,
    useRootNavigator: true,
    backgroundColor: ColorConstants.onyx,
    builder: (BuildContext context) {
      return StatsBottomSheetWidget();
    },
  );
}
