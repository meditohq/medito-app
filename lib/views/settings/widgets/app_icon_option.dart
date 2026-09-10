import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:medito/constants/constants.dart';
import 'package:medito/l10n/app_localizations.dart';

enum AppIconOption {
  defaultIcon(null, iosOnly: true),
  purple('purple', androidOnly: true),
  classic('classic'),
  nearblack('nearblack'),
  goldenHour('goldenhour', androidIconName: 'pink'),
  ocean('ocean'),
  forest('forest'),
  blush('blush');

  final String? iconName;
  final String? androidIconName;
  final bool androidOnly;
  final bool iosOnly;

  const AppIconOption(
    this.iconName, {
    this.androidIconName,
    this.androidOnly = false,
    this.iosOnly = false,
  });

  String? get effectiveIconName =>
      defaultTargetPlatform == TargetPlatform.android && androidIconName != null
      ? androidIconName
      : iconName;

  static List<AppIconOption> get availableOptions => values
      .where(
        (o) =>
            (!o.androidOnly ||
                defaultTargetPlatform == TargetPlatform.android) &&
            (!o.iosOnly || defaultTargetPlatform == TargetPlatform.iOS),
      )
      .toList();

  String get previewAsset {
    final name = iconName ?? 'default';
    return 'assets/images/app_icons/ios/$name.png';
  }

  List<Color> get gradientColors => switch (this) {
    AppIconOption.defaultIcon => [
      const Color(0xFFC86D8D),
      const Color(0xFFE9AEB6),
    ],
    AppIconOption.purple => [const Color(0xFF917CF0), const Color(0xFF917CF0)],
    AppIconOption.classic => [const Color(0xFFFFFFFF), const Color(0xFFFFFFFF)],
    AppIconOption.nearblack => [
      const Color(0xFF140116),
      const Color(0xFF2A1A2C),
    ],
    AppIconOption.ocean => [const Color(0xFF305A88), const Color(0xFF4A7CAE)],
    AppIconOption.forest => [const Color(0xFF67897B), const Color(0xFF3A6051)],
    AppIconOption.blush => [const Color(0xFFC86D8D), const Color(0xFFE9AEB6)],
    AppIconOption.goldenHour => [
      const Color(0xFFEB6A7E),
      const Color(0xFFF7CE46),
    ],
  };

  String displayName(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return switch (this) {
      AppIconOption.defaultIcon => l10n.appIconDefault,
      AppIconOption.purple => l10n.appIconPurple,
      AppIconOption.classic => l10n.appIconClassic,
      AppIconOption.nearblack => l10n.appIconNearBlack,
      AppIconOption.ocean => l10n.appIconOcean,
      AppIconOption.forest => l10n.appIconForest,
      AppIconOption.blush => l10n.appIconBlush,
      AppIconOption.goldenHour => l10n.appIconPink,
    };
  }
}

class AppIconPreview extends StatelessWidget {
  const AppIconPreview({super.key, required this.option, required this.size});

  final AppIconOption option;
  final double size;

  @override
  Widget build(BuildContext context) {
    final isClassic = option == AppIconOption.classic;

    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(size * 0.22),
        child: Image.asset(option.previewAsset, width: size, height: size),
      );
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.22),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: option.gradientColors,
        ),
      ),
      child: Center(
        child: SvgPicture.asset(
          AssetConstants.icLogo,
          width: size * 0.75,
          height: size * 0.75,
          colorFilter: ColorFilter.mode(
            isClassic
                ? const Color(0xFF8E7DE9)
                : Colors.white.withValues(alpha: 0.9),
            BlendMode.srcIn,
          ),
        ),
      ),
    );
  }
}
