import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

class MeditoHugeIcon extends StatelessWidget {
  const MeditoHugeIcon({
    super.key,
    required this.icon,
    this.color = Colors.white,
    this.size = 24,
  });

  final String icon;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return HugeIcon(
      icon: _getIconData(icon),
      color: color,
      size: size,
    );
  }

  IconData _getIconData(String iconString) {
    switch (iconString) {
      // custom ids:
      case 'duohome':
      case 'filledhome':
        return HugeIcons.solidRoundedHome01;
      case 'duoSearch':
      case 'filledSearch':
        return HugeIcons.solidRoundedSearch01;
      case 'duoSettings':
      case 'filledSettings':
        return HugeIcons.solidRoundedSettings01;
      // ids from the package:
      case 'bulkRoundedSun01':
        return HugeIcons.solidRoundedSun01;
      case 'bulkRoundedDownloadSquare02':
        return HugeIcons.solidRoundedDownloadSquare02;
      case 'bulkRoundedTime01':
        return HugeIcons.solidRoundedTime01;
      case 'duotoneRoundedSleeping':
        return HugeIcons.solidRoundedSleeping;
      case 'bulkRoundedMedal06':
        return HugeIcons.solidRoundedMedal06;
      case 'bulkRoundedHealtcare':
        return HugeIcons.solidRoundedHealtcare;
      case 'duotoneRoundedStar':
        return HugeIcons.solidRoundedStar;
      default:
        return HugeIcons.solidRoundedQuestion;
    }
  }
}
