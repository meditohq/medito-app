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
import 'package:medito/widgets/radio_option_card.dart';
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

const _kPreviewSize = 36.0;

/// Bottom sheet listing the available icons as radio option cards with a
/// preview of each. Pops with the chosen [AppIconOption].
class AppIconSheet extends StatelessWidget {
  const AppIconSheet({super.key, required this.current});

  final AppIconOption current;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final options = AppIconOption.availableOptions;
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;
    final maxHeight = MediaQuery.sizeOf(context).height * 0.8;

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Text(
                l10n.appIconTitle,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: onSurface,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                itemCount: options.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (context, i) {
                  final option = options[i];
                  return RadioOptionCard(
                    title: option.displayName(context),
                    selected: option == current,
                    // Hairline so the white Classic icon still reads as a
                    // tile on the light card surface.
                    trailing: Container(
                      // Foreground, or the icon paints over the edge.
                      foregroundDecoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(
                          _kPreviewSize * 0.22,
                        ),
                        border: Border.all(
                          color: onSurface.withValues(alpha: 0.18),
                          width: 1,
                        ),
                      ),
                      child: AppIconPreview(
                        option: option,
                        size: _kPreviewSize,
                      ),
                    ),
                    onTap: () => Navigator.of(context).pop(option),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
