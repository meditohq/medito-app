import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../constants/icons/medito_icons.dart';

class MeditoIcon extends StatelessWidget {
  const MeditoIcon({
    super.key,
    required this.assetName,
    this.color,
    this.size = 24,
    this.semanticLabel,
  });

  final String assetName;
  final Color? color;
  final double size;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    if (assetName.isEmpty) return const SizedBox.shrink();

    final iconColour = color ?? Theme.of(context).colorScheme.onSurface;

    if (assetName.endsWith('.svg')) {
      return SvgPicture.asset(
        assetName,
        width: size,
        height: size,
        fit: BoxFit.contain,
        colorFilter: ColorFilter.mode(iconColour, BlendMode.srcIn),
        semanticsLabel: semanticLabel,
      );
    }

    return Image.asset(
      assetName,
      width: size,
      height: size,
      semanticLabel: semanticLabel,
    );
  }
}

class MeditoHugeIcon extends StatelessWidget {
  static const String streakIcon = 'streak';

  const MeditoHugeIcon({
    super.key,
    required this.icon,
    this.color,
    this.size = 24,
  });

  final String icon;
  final Color? color;
  final double size;

  @override
  Widget build(BuildContext context) {
    if (icon.isEmpty) return const SizedBox.shrink();

    final asset = _iconAssetMap[icon] ?? MeditoIcons.help;

    return MeditoIcon(
      assetName: asset,
      color: color,
      size: size,
    );
  }

  static const Map<String, String> _iconAssetMap = {
    'Current Streak': MeditoIcons.fire,
    'Longest Streak': MeditoIcons.calendar,
    'Total Tracks Completed': MeditoIcons.playSolid,
    'Total Time Listened': MeditoIcons.hourglass,
    'Consistency Score': MeditoIcons.graphUp,
    streakIcon: MeditoIcons.fire,
    'duohome': MeditoIcons.home,
    'filledhome': MeditoIcons.home,
    'duoSearch': MeditoIcons.search,
    'filledSearch': MeditoIcons.search,
    'duoSettings': MeditoIcons.settings,
    'filledSettings': MeditoIcons.settings,
    'solidRoundedBook02': MeditoIcons.book,
    'solidRoundedSun01': MeditoIcons.sun,
    'solidRoundedDownloadSquare02': MeditoIcons.downloadCircleNew,
    'solidRoundedTime01': MeditoIcons.timerOutline,
    'solidRoundedSleeping': MeditoIcons.sleep,
    'solidRoundedMedal06': MeditoIcons.medalOutline,
    'solidRoundedHealtcare': MeditoIcons.health,
    'solidRoundedStar': MeditoIcons.star,
    'solidRoundedQuestion': MeditoIcons.help,
    'solidRoundedFire': MeditoIcons.fire,
    'solidRoundedCalendar01': MeditoIcons.calendar,
    'solidRoundedPlayCircle': MeditoIcons.playSolid,
    'solidRoundedHourglass': MeditoIcons.hourglass,
    'solidSharpChartIncrease': MeditoIcons.graphUp,
    'solidRoundedHome01': MeditoIcons.home,
    'solidRoundedSearch01': MeditoIcons.search,
    'solidRoundedSettings01': MeditoIcons.settings,
    'strokeRoundedMedal06': MeditoIcons.medalOutline,
    'strokeRoundedTime01': MeditoIcons.timerOutline,
    'strokeRoundedTimer01': MeditoIcons.timerOutline,
    'twotoneRoundedMedal06': MeditoIcons.medalOutline,
    'twotoneRoundedTime01': MeditoIcons.timerOutline,
    'twotoneRoundedTimer01': MeditoIcons.timerOutline,
    'duoMedal': MeditoIcons.medalOutline,
    'duoTimer': MeditoIcons.timerOutline,
    'duoTime': MeditoIcons.timerOutline,
    'filledMedal': MeditoIcons.medalOutline,
    'filledTimer': MeditoIcons.timerOutline,
    'filledTime': MeditoIcons.timerOutline,
    'strokeRoundedDownloadCircle01': MeditoIcons.downloadCircleNew,
    'strokeRoundedDownloadCircle02': MeditoIcons.downloadCircleNew,
    'twotoneRoundedDownloadCircle01': MeditoIcons.downloadCircleNew,
    'twotoneRoundedDownloadCircle02': MeditoIcons.downloadCircleNew,
    'duoDownloadCircle': MeditoIcons.downloadCircleNew,
    'filledDownloadCircle': MeditoIcons.downloadCircleNew,
  };
}
