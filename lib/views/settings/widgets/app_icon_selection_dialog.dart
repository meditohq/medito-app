import 'package:dynamic_app_icon_flutter_plus/dynamic_app_icon_flutter_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:medito/l10n/app_localizations.dart';
import 'package:medito/utils/utils.dart';
import 'package:medito/widgets/dialogs/dialogs.dart';

enum AppIconOption {
  defaultIcon(null, 'assets/images/app_icons/default.png'),
  purple('purple', 'assets/images/app_icons/purple.png', androidOnly: true),
  nearblack('nearblack', 'assets/images/app_icons/nearblack.png'),
  pink('pink', 'assets/images/app_icons/pink.png'),
  ocean('ocean', 'assets/images/app_icons/ocean.png'),
  forest('forest', 'assets/images/app_icons/forest.png'),
  blush('blush', 'assets/images/app_icons/blush.png');

  final String? iconName;
  final String previewAsset;
  final bool androidOnly;

  const AppIconOption(this.iconName, this.previewAsset, {this.androidOnly = false});

  static List<AppIconOption> get availableOptions => values
      .where((o) => !o.androidOnly || defaultTargetPlatform == TargetPlatform.android)
      .toList();

  String displayName(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return switch (this) {
      AppIconOption.defaultIcon => l10n.appIconDusk,
      AppIconOption.purple => l10n.appIconPurple,
      AppIconOption.nearblack => l10n.appIconNearBlack,
      AppIconOption.pink => l10n.appIconPink,
      AppIconOption.ocean => l10n.appIconOcean,
      AppIconOption.forest => l10n.appIconForest,
      AppIconOption.blush => l10n.appIconBlush,
    };
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
      await DynamicAppIconFlutterPlus.setAlternateIconName(option.iconName);
      setState(() => _currentIconName = option.iconName);
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
    final isSelected = _currentIconName == option.iconName;

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
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.asset(
                  option.previewAsset,
                  width: 48,
                  height: 48,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  option.displayName(context),
                  style: theme.textTheme.bodyMedium?.copyWith(
                        color: isSelected
                            ? theme.colorScheme.primary
                            : theme.colorScheme.onSurface,
                        fontWeight:
                            isSelected ? FontWeight.w600 : FontWeight.w400,
                      ),
                ),
              ),
              if (isSelected)
                Icon(
                  Icons.check,
                  size: 20,
                  color: theme.colorScheme.primary,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
