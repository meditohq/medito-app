import 'package:dynamic_app_icon_flutter_plus/dynamic_app_icon_flutter_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:medito/constants/constants.dart';
import 'package:medito/l10n/app_localizations.dart';
import 'package:medito/utils/utils.dart';
import 'package:medito/widgets/dialogs/dialogs.dart';

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

class AppIconSelectionDialog extends StatefulWidget {
  const AppIconSelectionDialog({super.key});

  @override
  State<AppIconSelectionDialog> createState() => AppIconSelectionDialogState();
}

class AppIconSelectionDialogState extends State<AppIconSelectionDialog> {
  String? _currentIconName;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCurrentIcon();
  }

  Future<void> _loadCurrentIcon() async {
    try {
      final name = await DynamicAppIconFlutterPlus.getAlternateIconName();
      setState(() {
        _currentIconName = name;
        _isLoading = false;
      });
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _setIcon(AppIconOption option) async {
    try {
      await DynamicAppIconFlutterPlus.setAlternateIconName(
        option.effectiveIconName,
      );
      setState(() => _currentIconName = option.effectiveIconName);
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (_) {
      if (mounted) {
        Navigator.of(context).pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    if (_isLoading) {
      return const MeditoDialog(
        child: Center(
          heightFactor: 1,
          child: Padding(
            padding: EdgeInsets.all(24),
            child: CircularProgressIndicator(),
          ),
        ),
      );
    }

    return MeditoDialog(
      title: l10n.appIconTitle,
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: AppIconOption.availableOptions
              .map((option) => _buildIconOption(context, option))
              .toList(),
        ),
      ),
      actions: [
        MeditoDialogSecondaryButton(
          label: l10n.cancel,
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }

  Widget _buildIconOption(BuildContext context, AppIconOption option) {
    final theme = Theme.of(context);
    final isSelected = _currentIconName == option.effectiveIconName;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () => _setIcon(option),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: isSelected
                ? theme.colorScheme.primary.withOpacityValue(0.1)
                : theme.cardColor,
            border: Border.all(
              color: isSelected
                  ? theme.colorScheme.primary.withOpacityValue(0.4)
                  : theme.colorScheme.outline.withOpacityValue(0.3),
              width: 0.5,
            ),
          ),
          child: Row(
            children: [
              AppIconPreview(option: option, size: 48),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  option.displayName(context),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: isSelected
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurface,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ),
              if (isSelected)
                Icon(Icons.check, size: 20, color: theme.colorScheme.primary),
            ],
          ),
        ),
      ),
    );
  }
}
