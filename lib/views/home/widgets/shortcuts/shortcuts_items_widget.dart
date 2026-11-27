// ignore_for_file: use_build_context_synchronously

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medito/constants/constants.dart';
import 'package:medito/constants/strings/analytics_event_constants.dart';
import 'package:medito/models/models.dart';
import 'package:medito/providers/providers.dart';
import 'package:medito/routes/routes.dart';
import 'package:medito/utils/utils.dart';

import '../../../../widgets/medito_icon.dart';
import '../../home_styles.dart';
import '../home_gradient_border.dart';

import 'package:medito/utils/session_origin.dart';

class ShortcutsItemsWidget extends ConsumerWidget {
  const ShortcutsItemsWidget({super.key, required this.data});

  static const _kItemBorderWidth = 0.5;
  static const _kItemBorderRadius = kHomeTileRadius;
  static const _kItemMinHeight = 48.0;
  static const _kItemHorizontalPadding = 14.0;
  static const _kIconSize = 24.0;
  static const _kIconGap = 12.0;

  final List<ShortcutsModel> data;

  void _handleChipPress(
    BuildContext context,
    WidgetRef ref,
    ShortcutsModel element,
  ) async {
    final analytics = ref.read(analyticsServiceProvider);
    unawaited(
      analytics.logEvent(
        name: AnalyticsEventConstants.shortcutTapped,
        parameters: {
          if (element.id != null)
            AnalyticsEventConstants.paramShortcutId: element.id!,
          if (element.title != null)
            AnalyticsEventConstants.paramShortcutTitle: element.title!,
          if (element.type != null)
            AnalyticsEventConstants.paramShortcutType: element.type!,
        },
      ),
    );
    unawaited(analytics.logFirstActionAfterOnboardingIfNeeded('shortcut'));
    await handleNavigation(
      element.type,
      [element.path.toString().getIdFromPath()],
      context,
      ref: ref,
      timerSource: AnalyticsEventConstants.sourceShortcut,
      sessionSource: SessionOrigin.homeShortcut,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Two columns of wide tiles (four on tablets), icon and label side by
    // side. The label sits inside its own tap target with half the screen to
    // itself, so "Challenges" and "Emergency" neither shrink nor crowd their
    // neighbours the way captions under four narrow squares did.
    final columns = MediaQuery.sizeOf(context).width > 600 ? 4 : 2;
    const spacing = 10.0;
    // Width left for a label inside its tile. Worked out from the screen
    // rather than a LayoutBuilder, which can't sit inside IntrinsicHeight.
    final tileWidth =
        (MediaQuery.sizeOf(context).width -
            padding16 * 2 -
            spacing * (columns - 1)) /
        columns;
    final labelWidth =
        tileWidth -
        _kItemBorderWidth * 2 -
        _kItemHorizontalPadding * 2 -
        _kIconSize -
        _kIconGap;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: padding16),
      child: Column(
        children: [
          for (var start = 0; start < data.length; start += columns) ...[
            if (start > 0) const SizedBox(height: spacing),
            // Tiles in a row share the tallest one's height, so a label that
            // wraps at large text sizes doesn't leave a ragged row.
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = start; i < start + columns; i++) ...[
                    if (i > start) const SizedBox(width: spacing),
                    Expanded(
                      child: i < data.length
                          ? _buildShortcutItem(
                              context,
                              ref,
                              data[i],
                              labelWidth,
                            )
                          : const SizedBox.shrink(),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildShortcutItem(
    BuildContext context,
    WidgetRef ref,
    ShortcutsModel e,
    double labelWidth,
  ) {
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;

    return Semantics(
      label: e.title,
      button: true,
      excludeSemantics: true,
      // excludeSemantics drops the child's tap action, so give it here.
      onTap: () => _handleChipPress(context, ref, e),
      child: HomeGradientBorder(
        backgroundColor: theme.cardColor,
        borderRadius: _kItemBorderRadius,
        borderWidth: _kItemBorderWidth,
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: () => _handleChipPress(context, ref, e),
            borderRadius: BorderRadius.circular(_kItemBorderRadius),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: _kItemMinHeight),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: _kItemHorizontalPadding,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    MeditoRemoteIcon(
                      icon: e.icon ?? '',
                      size: _kIconSize,
                      color: onSurface,
                    ),
                    const SizedBox(width: _kIconGap),
                    Expanded(
                      child: _ShortcutTitle(
                        title: e.title ?? '',
                        style: context.text.label,
                        maxWidth: labelWidth,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A shortcut's label. Wraps between words onto two lines at large text
/// sizes; only when a single word is wider than the tile is the label scaled
/// down to fit, so "Downloads" never breaks into "Download" and "s".
class _ShortcutTitle extends StatelessWidget {
  const _ShortcutTitle({
    required this.title,
    required this.style,
    required this.maxWidth,
  });

  final String title;
  final TextStyle? style;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final textScaler = MediaQuery.textScalerOf(context);
    final direction = Directionality.of(context);
    final wordTooWide = title.split(RegExp(r'\s+')).any((word) {
      final painter = TextPainter(
        text: TextSpan(text: word, style: style),
        textDirection: direction,
        textScaler: textScaler,
        maxLines: 1,
      )..layout();
      final width = painter.width;
      painter.dispose();
      return width > maxWidth;
    });

    if (wordTooWide) {
      return FittedBox(
        fit: BoxFit.scaleDown,
        alignment: AlignmentDirectional.centerStart,
        child: Text(title, style: style, maxLines: 1),
      );
    }
    return Text(
      title,
      style: style,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  }
}
