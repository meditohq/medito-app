import 'dart:io';

import 'package:dynamic_app_icon_flutter_plus/dynamic_app_icon_flutter_plus.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:medito/l10n/app_localizations.dart';
import 'package:medito/src/audio_pigeon.g.dart';
import 'package:medito/utils/logger.dart';
import 'package:medito/views/home/widgets/bottom_sheet/row_item_widget.dart';
import 'package:medito/views/settings/widgets/app_icon_option.dart';
import 'package:medito/widgets/snackbar_widget.dart';

/// Settings row for the home-screen icon: shows the current icon as a preview
/// and opens [AppIconSheet] on tap.
class AppIconTile extends StatefulWidget {
  const AppIconTile({
    super.key,
    required this.icon,
    required this.title,
    this.hasUnderline = true,
  });

  final Widget icon;
  final String title;
  final bool hasUnderline;

  @override
  State<AppIconTile> createState() => _AppIconTileState();
}

class _AppIconTileState extends State<AppIconTile> {
  String? _currentIconName;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _loadCurrentIcon();
  }

  Future<void> _loadCurrentIcon() async {
    // No alternate icons on web (widget previewer); dart:io Platform would throw.
    if (kIsWeb) return;
    try {
      final name = Platform.isAndroid
          ? await MeditoAppIconManager().getAlternateIconName()
          : await DynamicAppIconFlutterPlus.getAlternateIconName();
      if (mounted) setState(() => _currentIconName = name);
    } catch (e, st) {
      AppLogger.e('AppIcon', 'Failed to load current icon', e, st);
    }
  }

  AppIconOption get _current {
    final options = AppIconOption.availableOptions;
    return options.firstWhere(
      (o) => o.effectiveIconName == _currentIconName,
      orElse: () => options.first,
    );
  }

  Future<void> _openSheet() async {
    if (_busy) return;
    final picked = await showModalBottomSheet<AppIconOption>(
      context: context,
      showDragHandle: true,
      backgroundColor: Theme.of(context).bottomSheetTheme.backgroundColor,
      builder: (_) => AppIconSheet(current: _current),
    );
    if (picked == null || !mounted || picked == _current) return;
    await _setIcon(picked);
  }

  Future<void> _setIcon(AppIconOption option) async {
    setState(() => _busy = true);
    try {
      final name = option.effectiveIconName;
      if (!kIsWeb && Platform.isAndroid) {
        await MeditoAppIconManager().setAlternateIconName(name);
        if (mounted) {
          setState(() => _currentIconName = name);
          showSnackBar(context, AppLocalizations.of(context)!.appIconChanged);
        }
        // Android swaps launcher aliases, which kills the process; leave
        // cleanly after the snackbar has been seen.
        await Future.delayed(const Duration(seconds: 1));
        await SystemNavigator.pop();
      } else if (!kIsWeb) {
        await DynamicAppIconFlutterPlus.setAlternateIconName(name);
        if (mounted) setState(() => _currentIconName = name);
      } else {
        if (mounted) setState(() => _currentIconName = name);
      }
    } catch (e, st) {
      AppLogger.e('AppIcon', 'Failed to set icon', e, st);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final current = _current;
    return RowItemWidget(
      icon: widget.icon,
      title: widget.title,
      subTitle: current.displayName(context),
      hasUnderline: widget.hasUnderline,
      trailing: AppIconPreview(option: current, size: 28),
      onTap: _busy ? null : _openSheet,
    );
  }
}

/// Bottom sheet listing the available icons with a preview of each. Pops with
/// the chosen [AppIconOption].
class AppIconSheet extends StatelessWidget {
  const AppIconSheet({super.key, required this.current});

  final AppIconOption current;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final options = AppIconOption.availableOptions;
    final onSurface = Theme.of(context).colorScheme.onSurface;

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(
              l10n.appIconTitle,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              children: [
                for (final (i, option) in options.indexed)
                  RowItemWidget(
                    icon: AppIconPreview(option: option, size: 36),
                    leadingIconSize: 36,
                    title: option.displayName(context),
                    hasUnderline: i < options.length - 1,
                    isTrailingIcon: option == current,
                    trailingIcon: Icons.check_rounded,
                    onTap: () => Navigator.of(context).pop(option),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
