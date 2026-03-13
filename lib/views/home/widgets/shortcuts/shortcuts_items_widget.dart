// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medito/constants/constants.dart';
import 'package:medito/models/models.dart';
import 'package:medito/routes/routes.dart';
import 'package:medito/utils/utils.dart';

import '../../../../widgets/medito_huge_icon.dart';
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
    final horizontalPadding = 16.0;
    final spacing = 20.0;
    final runSpacing = 12.0;
    final totalSpacing = (columns - 1) * spacing;
    final totalPadding = horizontalPadding * 2;
    final containerSize = (size.width - totalPadding - totalSpacing) / columns;

    return Padding(
      padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
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

  bool _isCourses(String? title) {
    return title?.toLowerCase() == 'courses';
  }

  Widget _buildShortcutItem(
    BuildContext context,
    WidgetRef ref,
    ShortcutsModel e,
    double width,
    double height,
  ) {
    final isCourses = _isCourses(e.title);
    final backgroundColor = isCourses
        ? ColorConstants.lightPurple
        : (e.isHighlighted
              ? ColorConstants.brightSky
              : Theme.of(context).cardColor);
    final iconColor = isCourses
        ? Colors.white
        : (e.isHighlighted
              ? ColorConstants.onyx
              : Theme.of(context).colorScheme.onSurface);
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
          color: Colors.transparent,
          child: InkWell(
            onTap: () => _handleChipPress(context, ref, e),
            borderRadius: BorderRadius.circular(
              _kItemBorderRadius - _kItemBorderWidth,
            ),
            child: Center(
              child: MeditoHugeIcon(
                icon: e.icon ?? '',
                size: iconSize,
                color: iconColor,
              ),
            ),
          ),
        ),
      ),
    );

    return SizedBox(
      width: width,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          squareButton,
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              e.title ?? '',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontFamily: teachers,
                fontSize: 12,
                color: textColor,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}
