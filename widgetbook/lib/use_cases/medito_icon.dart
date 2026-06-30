import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:medito/constants/icons/medito_icons.dart';
import 'package:medito/widgets/medito_icon.dart';
import 'package:widgetbook/widgetbook.dart';
import 'package:widgetbook_annotation/widgetbook_annotation.dart';

const _allIcons = <String, String>{
  'arrowLeft': MeditoIcons.arrowLeft,
  'arrowRight': MeditoIcons.arrowRight,
  'alert': MeditoIcons.alert,
  'backward15': MeditoIcons.backward15,
  'bell': MeditoIcons.bell,
  'book': MeditoIcons.book,
  'bookSolid': MeditoIcons.bookSolid,
  'calendar': MeditoIcons.calendar,
  'check': MeditoIcons.check,
  'checkCircle': MeditoIcons.checkCircle,
  'checkCircleSolid': MeditoIcons.checkCircleSolid,
  'compactDisc': MeditoIcons.compactDisc,
  'compactDiscSolid': MeditoIcons.compactDiscSolid,
  'document': MeditoIcons.document,
  'dragHandle': MeditoIcons.dragHandle,
  'downloadCircle': MeditoIcons.downloadCircle,
  'downloadCircleNew': MeditoIcons.downloadCircleNew,
  'downloadCircleSolid': MeditoIcons.downloadCircleSolid,
  'downloadSquare': MeditoIcons.downloadSquare,
  'fire': MeditoIcons.fire,
  'forward15': MeditoIcons.forward15,
  'graphUp': MeditoIcons.graphUp,
  'heart': MeditoIcons.heart,
  'health': MeditoIcons.health,
  'help': MeditoIcons.help,
  'home': MeditoIcons.home,
  'hourglass': MeditoIcons.hourglass,
  'libraries': MeditoIcons.libraries,
  'login': MeditoIcons.login,
  'logout': MeditoIcons.logout,
  'medal': MeditoIcons.medal,
  'medalOutline': MeditoIcons.medalOutline,
  'moon': MeditoIcons.moon,
  'musicNote': MeditoIcons.musicNote,
  'pause': MeditoIcons.pause,
  'pin': MeditoIcons.pin,
  'pinSolid': MeditoIcons.pinSolid,
  'play': MeditoIcons.play,
  'playSolid': MeditoIcons.playSolid,
  'pencil': MeditoIcons.pencil,
  'privacy': MeditoIcons.privacy,
  'profile': MeditoIcons.profile,
  'repeat': MeditoIcons.repeat,
  'repeatOnce': MeditoIcons.repeatOnce,
  'road': MeditoIcons.road,
  'search': MeditoIcons.search,
  'settings': MeditoIcons.settings,
  'shareAndroid': MeditoIcons.shareAndroid,
  'shareIos': MeditoIcons.shareIos,
  'shield': MeditoIcons.shield,
  'shop': MeditoIcons.shop,
  'siri': MeditoIcons.siri,
  'sleep': MeditoIcons.sleep,
  'snow': MeditoIcons.snow,
  'star': MeditoIcons.star,
  'starSolid': MeditoIcons.starSolid,
  'sun': MeditoIcons.sun,
  'telegram': MeditoIcons.telegram,
  'timer': MeditoIcons.timer,
  'timerOutline': MeditoIcons.timerOutline,
  'whatsapp': MeditoIcons.whatsapp,
  'xmark': MeditoIcons.xmark,
};

@UseCase(name: 'All icons', type: MeditoIcon)
Widget allMeditoIcons(BuildContext context) {
  final size = context.knobs.double.slider(
    label: 'Size',
    initialValue: 24,
    min: 16,
    max: 64,
  );

  return SingleChildScrollView(
    padding: const EdgeInsets.all(24),
    child: Wrap(
      spacing: 24,
      runSpacing: 24,
      children: _allIcons.entries
          .map((e) => _IconTile(name: e.key, assetName: e.value, size: size))
          .toList(),
    ),
  );
}

@UseCase(name: 'Single icon', type: MeditoIcon)
Widget singleMeditoIcon(BuildContext context) {
  final name = context.knobs.object.dropdown(
    label: 'Icon',
    options: _allIcons.keys.toList(),
    initialOption: 'heart',
  );
  final size = context.knobs.double.slider(
    label: 'Size',
    initialValue: 32,
    min: 16,
    max: 96,
  );

  return Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        MeditoIcon(assetName: _allIcons[name]!, size: size),
        const SizedBox(height: 12),
        Text(name, style: Theme.of(context).textTheme.bodySmall),
      ],
    ),
  );
}

@UseCase(name: 'Remote icon keys', type: MeditoRemoteIcon)
Widget meditoRemoteIconUseCase(BuildContext context) {
  final size = context.knobs.double.slider(
    label: 'Size',
    initialValue: 32,
    min: 16,
    max: 64,
  );

  const hugeIcons = [
    'Current Streak',
    'Longest Streak',
    'Total Tracks Completed',
    'Total Time Listened',
    'Consistency Score',
    'streak',
    'duohome',
    'filledhome',
    'duoSearch',
    'filledSearch',
    'duoSettings',
    'filledSettings',
  ];

  return SingleChildScrollView(
    padding: const EdgeInsets.all(24),
    child: Wrap(
      spacing: 24,
      runSpacing: 24,
      children: hugeIcons
          .map(
            (icon) => _IconTile(
              name: icon,
              assetName: null,
              size: size,
              hugeIcon: icon,
            ),
          )
          .toList(),
    ),
  );
}

class _IconTile extends StatelessWidget {
  const _IconTile({
    required this.name,
    required this.size,
    this.assetName,
    this.hugeIcon,
  });

  final String name;
  final String? assetName;
  final String? hugeIcon;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 80,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: size + 16,
            height: size + 16,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
            ),
            alignment: Alignment.center,
            child: hugeIcon != null
                ? SvgPicture.asset(
                    MeditoRemoteIcon.assetForKey(hugeIcon!),
                    width: size,
                    height: size,
                  )
                : SvgPicture.asset(assetName!, width: size, height: size),
          ),
          const SizedBox(height: 6),
          Text(
            name,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(fontSize: 10),
          ),
        ],
      ),
    );
  }
}
