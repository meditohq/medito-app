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
import '../home_gradient_border.dart';

class ShortcutsItemsWidget extends ConsumerWidget {
  const ShortcutsItemsWidget({super.key, required this.data});

  static const _kItemBorderWidth = 0.5;
  static const _kItemBorderRadius = 24.0;

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
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var size = MediaQuery.of(context).size;
    var isWideScreen = size.width > 600;
    final columns = isWideScreen ? 8 : 4;
    const horizontalPadding = padding16;
    const spacing = padding12;
    const runSpacing = 10.0;
    final totalSpacing = (columns - 1) * spacing;
    final totalPadding = horizontalPadding * 2;
    final containerSize = (size.width - totalPadding - totalSpacing) / columns;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: padding16),
      child: Wrap(
        spacing: spacing,
        runSpacing: runSpacing,
        alignment: WrapAlignment.start,
        children: data
            .map(
              (e) => _buildShortcutItem(
                context,
                ref,
                e,
                containerSize,
                containerSize,
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _buildShortcutItem(
    BuildContext context,
    WidgetRef ref,
    ShortcutsModel e,
    double width,
    double height,
  ) {
    final backgroundColor = Theme.of(context).cardColor;
    final iconColor = Theme.of(context).colorScheme.onSurface;
    final textColor = Theme.of(context).colorScheme.onSurface;

    final iconSize = (width * 0.5).clamp(24.0, 32.0);

    final squareButton = HomeGradientBorder(
      backgroundColor: backgroundColor,
      borderRadius: _kItemBorderRadius,
      borderWidth: _kItemBorderWidth,
      child: SizedBox(
        width: width,
        height: width,
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: () => _handleChipPress(context, ref, e),
            child: Center(
              child: MeditoRemoteIcon(
                icon: e.icon ?? '',
                size: iconSize,
                color: iconColor,
              ),
            ),
          ),
        ),
      ),
    );

    return Semantics(
      label: e.title,
      button: true,
      excludeSemantics: true,
      child: SizedBox(
        width: width,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            squareButton,
            GestureDetector(
              onTap: () => _handleChipPress(context, ref, e),
              child: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    e.title ?? '',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontFamily: teachers,
                      fontSize: 12,
                      color: textColor.withOpacityValue(0.7),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
