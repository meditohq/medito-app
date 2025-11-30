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
  late List<ShortcutsModel> data;
  bool _isReordering = false;

  String _getItemKey(ShortcutsModel e) => e.id ?? '${e.type}_${e.path}';

  List<String> _getItemKeys(List<ShortcutsModel> items) =>
      items.map(_getItemKey).toList();

  bool _areOrdersEqual(List<ShortcutsModel> a, List<ShortcutsModel> b) {
    if (a.length != b.length) return false;
    final keysA = _getItemKeys(a);
    final keysB = _getItemKeys(b);
    for (var i = 0; i < keysA.length; i++) {
      if (keysA[i] != keysB[i]) return false;
    }
    return true;
  }

  @override
  void initState() {
    super.initState();
    data = widget.data.toList();
    AppLogger.d('ShortcutsItemsWidget', 'initState: ${data.length} items');
    AppLogger.d(
        'ShortcutsItemsWidget', 'Item IDs: ${data.map((e) => e.id).toList()}');
  }

  @override
  void didUpdateWidget(covariant ShortcutsItemsWidget oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (_isReordering) {
      AppLogger.d('ShortcutsItemsWidget',
          'didUpdateWidget: Skipping update - reorder in progress');
      return;
    }

    final ordersEqual = _areOrdersEqual(widget.data, data);
    AppLogger.d('ShortcutsItemsWidget',
        'didUpdateWidget: ordersEqual=$ordersEqual, widget.data.length=${widget.data.length}, data.length=${data.length}');

    if (!ordersEqual && widget.data.length == data.length) {
      AppLogger.d('ShortcutsItemsWidget',
          'Updating data - order changed or items changed');
      AppLogger.d('ShortcutsItemsWidget', 'Old order: ${_getItemKeys(data)}');
      AppLogger.d(
          'ShortcutsItemsWidget', 'New order: ${_getItemKeys(widget.data)}');

      data = widget.data.toList();
      AppLogger.d('ShortcutsItemsWidget', 'Updated local data order');
    } else if (widget.data.length != data.length) {
      AppLogger.d('ShortcutsItemsWidget', 'Item count changed, updating data');
      data = widget.data.toList();
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

  void _onReorder(int oldIndex, int newIndex) {
    AppLogger.d('ShortcutsItemsWidget',
        '_onReorder called: oldIndex=$oldIndex, newIndex=$newIndex');
    AppLogger.d(
        'ShortcutsItemsWidget', 'Before reorder - data length: ${data.length}');
    AppLogger.d('ShortcutsItemsWidget',
        'Before reorder - IDs: ${data.map((e) => e.id).toList()}');

    setState(() {
      final element = data.removeAt(oldIndex);
      AppLogger.d('ShortcutsItemsWidget',
          'Removed element at $oldIndex: id=${element.id}, title=${element.title}');
      data.insert(newIndex, element);
      AppLogger.d('ShortcutsItemsWidget',
          'After reorder - IDs: ${data.map((e) => e.id).toList()}');
      _handleShortcutItemPlacementInPreference(oldIndex, newIndex);
    });
  }

  Future<void> _handleShortcutItemPlacementInPreference(
    int oldIndex,
    int newIndex,
  ) async {
    _isReordering = true;
    AppLogger.d('ShortcutsItemsWidget',
        '_handleShortcutItemPlacementInPreference: oldIndex=$oldIndex, newIndex=$newIndex');

    var ids = data.map((e) {
      if (e.id != null) {
        return e.id!;
      }
      return '${e.type}_${e.path}';
    }).toList();

    AppLogger.d('ShortcutsItemsWidget', 'Saving IDs to preference: $ids');
    AppLogger.d('ShortcutsItemsWidget',
        'Items with null IDs: ${data.where((e) => e.id == null).map((e) => '${e.type}_${e.path}').toList()}');

    try {
      await ref.read(updateShortcutsIdsInPreferenceProvider(ids: ids).future);
      AppLogger.d('ShortcutsItemsWidget',
          'Successfully updated shortcuts in preference');
      await ref.read(refreshHomeAPIsProvider.future);
      AppLogger.d('ShortcutsItemsWidget', 'Successfully refreshed home APIs');
    } catch (e, stackTrace) {
      AppLogger.e('ShortcutsItemsWidget', 'Error updating shortcuts preference',
          e, stackTrace);
    } finally {
      _isReordering = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    AppLogger.d('ShortcutsItemsWidget',
        'build: data length=${data.length}, widget.data length=${widget.data.length}');
    var size = MediaQuery.of(context).size;
    var isWideScreen = size.width > 600;
    final columns = isWideScreen ? 8 : 4;
    final horizontalPadding = 16.0;
    final spacing = 20.0;
    final runSpacing = 12.0;
    final totalSpacing = (columns - 1) * spacing;
    final totalPadding = horizontalPadding * 2;
    final containerSize = (size.width - totalPadding - totalSpacing) / columns;

    AppLogger.d('ShortcutsItemsWidget',
        'Building ReorderableWrap with ${data.length} children, columns=$columns');

    return ReorderableWrap(
      spacing: spacing,
      runSpacing: runSpacing,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      maxMainAxisCount: columns,
      minMainAxisCount: columns,
      onReorder: _onReorder,
      children: data
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
    AppLogger.d('ShortcutsItemsWidget',
        'Building item with key: $uniqueKey (id: ${e.id}, type: ${e.type}, path: ${e.path})');

    final borderColor =
        Color.lerp(backgroundColor, Colors.white, 0.3) ?? backgroundColor;

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
              size: 32,
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
          Text(
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
        ],
      ),
    );
  }
}
