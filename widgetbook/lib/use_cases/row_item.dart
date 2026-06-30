import 'package:flutter/material.dart';
import 'package:medito/constants/icons/medito_icons.dart';
import 'package:medito/views/home/widgets/bottom_sheet/row_item_widget.dart';
import 'package:medito/widgets/medito_icon.dart';
import 'package:widgetbook/widgetbook.dart';
import 'package:widgetbook_annotation/widgetbook_annotation.dart';

@UseCase(name: 'With chevron', type: RowItemWidget)
Widget rowItemWithChevron(BuildContext context) {
  return Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      RowItemWidget(
        title: context.knobs.string(
          label: 'Title',
          initialValue: 'Notifications',
        ),
        subTitle: context.knobs.stringOrNull(
          label: 'Subtitle',
          initialValue: null,
        ),
        icon: const MeditoIcon(assetName: MeditoIcons.bell),
        hasUnderline: context.knobs.boolean(
          label: 'Underline',
          initialValue: true,
        ),
        onTap: () {},
      ),
    ],
  );
}

@UseCase(name: 'With switch', type: RowItemWidget)
Widget rowItemWithSwitch(BuildContext context) {
  return Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      RowItemWidget(
        title: 'Do Not Disturb',
        subTitle: 'Silence all alerts',
        icon: const MeditoIcon(assetName: MeditoIcons.bell),
        isTrailingIcon: false,
        isSwitch: true,
        switchValue: context.knobs.boolean(
          label: 'Switch value',
          initialValue: false,
        ),
        onSwitchChanged: (_) {},
      ),
    ],
  );
}

@UseCase(name: 'List', type: RowItemWidget)
Widget rowItemList(BuildContext context) {
  return Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      RowItemWidget(
        title: 'Notifications',
        icon: const MeditoIcon(assetName: MeditoIcons.bell),
        onTap: () {},
      ),
      RowItemWidget(
        title: 'Downloads',
        icon: const MeditoIcon(assetName: MeditoIcons.downloadCircle),
        onTap: () {},
      ),
      RowItemWidget(
        title: 'Help & Support',
        icon: const MeditoIcon(assetName: MeditoIcons.help),
        hasUnderline: false,
        onTap: () {},
      ),
    ],
  );
}
