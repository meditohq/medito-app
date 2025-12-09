// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medito/constants/constants.dart';
import 'package:medito/models/models.dart';
import 'package:medito/providers/providers.dart';
import 'package:medito/routes/routes.dart';
import 'package:medito/utils/utils.dart';
import 'package:reorderables/reorderables.dart';

import '../../../../providers/home/home_provider.dart';
import '../../../../utils/logger.dart';
import '../../../../widgets/medito_huge_icon.dart';

class ShortcutsItemsWidget extends ConsumerStatefulWidget {
  const ShortcutsItemsWidget({super.key, required this.data});

  final List<ShortcutsModel> data;

  @override
  ConsumerState<ShortcutsItemsWidget> createState() =>
      _ShortcutsItemsWidgetState();
}

class _ShortcutsItemsWidgetState extends ConsumerState<ShortcutsItemsWidget> {
  late List<ShortcutsModel> _localData;

  String _getItemKey(ShortcutsModel e) => e.id ?? '${e.type}_${e.path}';

  @override
  void initState() {
    super.initState();
    _localData = List.from(widget.data);
  }

  @override
  void didUpdateWidget(covariant ShortcutsItemsWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.data.length != _localData.length) {
      _localData = List.from(widget.data);
    } else {
      final currentKeys = _localData.map(_getItemKey).toList();
      final newKeys = widget.data.map(_getItemKey).toList();
      final currentKeysSet = currentKeys.toSet();
      final newKeysSet = newKeys.toSet();
      if (currentKeysSet.length != newKeysSet.length ||
          !currentKeysSet.containsAll(newKeysSet)) {
        _localData = List.from(widget.data);
      }
    }
  }

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

  Future<void> _onReorder(int oldIndex, int newIndex) async {
    if (oldIndex == newIndex) return;

    setState(() {
      final element = _localData.removeAt(oldIndex);
      _localData.insert(newIndex, element);
    });

    final ids = _localData.map((e) => _getItemKey(e)).toList();

    try {
      await ref.read(updateShortcutsIdsInPreferenceProvider(ids: ids).future);
      await ref.read(refreshHomeAPIsProvider.future);
    } catch (e, stackTrace) {
      AppLogger.e('ShortcutsItemsWidget', 'Error updating shortcuts preference',
          e, stackTrace);
      setState(() {
        _localData = List.from(widget.data);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    var size = MediaQuery.of(context).size;
    var isWideScreen = size.width > 600;
    final columns = isWideScreen ? 8 : 4;
    final horizontalPadding = 16.0;
    final spacing = 20.0;
    final runSpacing = 12.0;
    final totalSpacing = (columns - 1) * spacing;
    final totalPadding = horizontalPadding * 2;
    final containerSize = (size.width - totalPadding - totalSpacing) / columns;

    return ReorderableWrap(
      spacing: spacing,
      runSpacing: runSpacing,
      padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
      maxMainAxisCount: columns,
      minMainAxisCount: columns,
      onReorder: _onReorder,
      children: _localData
          .map((e) => _buildShortcutItem(e, containerSize, containerSize))
          .toList(),
    );
  }

  bool _isCourses(String? title) {
    return title?.toLowerCase() == 'courses';
  }

  Widget _buildShortcutItem(ShortcutsModel e, double width, double height) {
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

    final uniqueKey = _getItemKey(e);

    final borderColor =
        Color.lerp(backgroundColor, Colors.white, 0.3) ?? backgroundColor;

    final iconSize = (width * 0.5).clamp(24.0, 32.0);

    final squareButton = Container(
      width: width,
      height: width,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: borderColor,
          width: 0.5,
        ),
        boxShadow: isCourses
            ? [
                BoxShadow(
                  color: ColorConstants.lightPurple.withOpacity(0.5),
                  blurRadius: 12,
                  spreadRadius: 2,
                ),
              ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _handleChipPress(context, ref, e),
          borderRadius: BorderRadius.circular(24),
          child: Center(
            child: MeditoHugeIcon(
              icon: e.icon ?? '',
              size: iconSize,
              color: iconColor,
            ),
          ),
        ),
      ),
    );

    return SizedBox(
      key: ValueKey(uniqueKey),
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
