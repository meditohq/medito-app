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
import 'package:medito/constants/constants.dart';
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
      isScrollControlled: true,
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

const _kPreviewSize = 60.0;

/// Bottom sheet showing the available icons as a grid of large previews with
/// their names; the current one gets a ring. The icon is what's being chosen,
/// so it leads rather than sitting small beside a text label. Pops with the
/// chosen [AppIconOption].
class AppIconSheet extends StatelessWidget {
  const AppIconSheet({super.key, required this.current});

  final AppIconOption current;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final options = AppIconOption.availableOptions;
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.appIconTitle,
              style: theme.textTheme.titleMedium?.copyWith(
                color: onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            LayoutBuilder(
              builder: (context, constraints) {
                const columns = 4;
                final tileWidth = constraints.maxWidth / columns;
                return Wrap(
                  runSpacing: 16,
                  children: [
                    for (final option in options)
                      SizedBox(
                        width: tileWidth,
                        child: _AppIconChoice(
                          option: option,
                          selected: option == current,
                          onTap: () => Navigator.of(context).pop(option),
                        ),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _AppIconChoice extends StatelessWidget {
  const _AppIconChoice({
    required this.option,
    required this.selected,
    required this.onTap,
  });

  final AppIconOption option;
  final bool selected;
  final VoidCallback onTap;

  static const _ringGap = 3.0;
  static const _ringWidth = 2.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;
    final accent = context.brandPurple;
    const radius = _kPreviewSize * 0.22;
    const ringInset = _ringGap + _ringWidth;

    return Semantics(
      inMutuallyExclusiveGroup: true,
      checked: selected,
      button: true,
      label: option.displayName(context),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: ExcludeSemantics(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOut,
                  padding: const EdgeInsets.all(_ringGap),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(radius + ringInset),
                    border: Border.all(
                      color: selected ? accent : Colors.transparent,
                      width: _ringWidth,
                    ),
                  ),
                  // Hairline so the white Classic icon still reads as a tile
                  // on a light surface. Foreground, or the icon paints over it.
                  child: Container(
                    foregroundDecoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(radius),
                      border: Border.all(
                        color: onSurface.withValues(alpha: 0.18),
                        width: 1,
                      ),
                    ),
                    child: AppIconPreview(option: option, size: _kPreviewSize),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  option.displayName(context),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontSize: 12,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                    color: onSurface.withValues(alpha: selected ? 1 : 0.7),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
