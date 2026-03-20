import 'package:flutter/material.dart';
import 'package:medito/constants/icons/medito_icons.dart';
import 'package:medito/widgets/medito_huge_icon.dart';
import 'package:widgetbook/widgetbook.dart';
import 'package:widgetbook_annotation/widgetbook_annotation.dart';

@UseCase(name: 'MeditoIcon', type: MeditoIcon)
Widget meditoIconUseCase(BuildContext context) {
  final size = context.knobs.double.slider(
    label: 'Size',
    initialValue: 24,
    min: 16,
    max: 64,
  );

  return Center(
    child: Wrap(
      spacing: 16,
      runSpacing: 16,
      alignment: WrapAlignment.center,
      children: [
        MeditoIcons.heart,
        MeditoIcons.bell,
        MeditoIcons.home,
        MeditoIcons.search,
        MeditoIcons.settings,
        MeditoIcons.fire,
        MeditoIcons.calendar,
        MeditoIcons.book,
        MeditoIcons.help,
        MeditoIcons.star,
      ].map((icon) => MeditoIcon(assetName: icon, size: size)).toList(),
    ),
  );
}

@UseCase(name: 'MeditoHugeIcon', type: MeditoHugeIcon)
Widget meditoHugeIconUseCase(BuildContext context) {
  final size = context.knobs.double.slider(
    label: 'Size',
    initialValue: 32,
    min: 16,
    max: 64,
  );

  return Center(
    child: Wrap(
      spacing: 16,
      runSpacing: 16,
      alignment: WrapAlignment.center,
      children: [
        'Current Streak',
        'Longest Streak',
        'Total Tracks Completed',
        'Total Time Listened',
        'Consistency Score',
      ].map((icon) => MeditoHugeIcon(icon: icon, size: size)).toList(),
    ),
  );
}
