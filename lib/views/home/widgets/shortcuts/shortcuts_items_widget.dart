import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medito/constants/constants.dart';
import 'package:medito/models/models.dart';
import 'package:medito/providers/providers.dart';
import 'package:medito/routes/routes.dart';
import 'package:medito/utils/utils.dart';
import 'package:reorderables/reorderables.dart';

import '../../../../providers/home/home_provider.dart';
import '../../../../widgets/medito_huge_icon.dart';
import '../animated_scale_widget.dart';

class ShortcutsItemsWidget extends ConsumerStatefulWidget {
  const ShortcutsItemsWidget({super.key, required this.data});

  final List<ShortcutsModel> data;

  @override
  ConsumerState<ShortcutsItemsWidget> createState() =>
      _ShortcutsItemsWidgetState();
}

class _ShortcutsItemsWidgetState extends ConsumerState<ShortcutsItemsWidget> {
  late List<ShortcutsModel> data;
  late List<Widget> shortcutsWidgetList = [];

  @override
  void didChangeDependencies() {
    data = widget.data;
    shortcutsWidgetList = _getShortcutsItemWidgetList();
    super.didChangeDependencies();
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
    setState(() {
      _handleShortcutWidgetPlacement(newIndex, oldIndex);
      _handleShortcutItemPlacementInPreference(oldIndex, newIndex);
    });
  }

  Future<void> _handleShortcutItemPlacementInPreference(
    int oldIndex,
    int newIndex,
  ) async {
    var updatedData = [...data];
    final element = updatedData.removeAt(oldIndex);
    updatedData.insert(newIndex, element);
    data = updatedData;
    var ids = updatedData.map((e) => e.id).whereType<String>().toList();
    await ref.read(updateShortcutsIdsInPreferenceProvider(ids: ids).future);

    await ref.read(refreshHomeAPIsProvider.future);
  }

  void _handleShortcutWidgetPlacement(int newIndex, int oldIndex) {
    shortcutsWidgetList.insert(
      newIndex,
      shortcutsWidgetList.removeAt(oldIndex),
    );
  }

  @override
  Widget build(BuildContext context) {
    var size = MediaQuery.of(context).size;
    var isWideScreen = size.width > 600; 

    return ReorderableWrap(
      spacing: 8.0,
      runSpacing: 8.0,
      padding: EdgeInsets.zero,
      maxMainAxisCount: isWideScreen ? 3 : 2,
      minMainAxisCount: isWideScreen ? 3 : 2,
      onReorder: _onReorder,
      children: shortcutsWidgetList,
    );
  }

  List<Widget> _getShortcutsItemWidgetList() {
    var size = MediaQuery.of(context).size;
    var isWideScreen = size.width > 600;
    const containerHeight = 48.0;
    final containerWidth = (size.width / (isWideScreen ? 3 : 2)) - (isWideScreen ? 16 : 19);

    return data
        .map((e) => AnimatedScaleWidget(
              child: IntrinsicWidth(
                child: InkWell(
                  key: ValueKey(e.id),
                  onTap: () => _handleChipPress(context, ref, e),
                  child: Container(
                    height: containerHeight,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      color: e.isHighlighted
                          ? ColorConstants.brightSky
                          : ColorConstants.onyx,
                    ),
                    padding: const EdgeInsets.all(12),
                    constraints: BoxConstraints(
                      maxWidth: containerWidth,
                      minWidth: containerWidth,
                    ),
                    child: Row(
                      children: [
                        MeditoHugeIcon(
                          icon: e.icon ?? '',
                          size: 18,
                          color: e.isHighlighted
                              ? ColorConstants.onyx
                              : ColorConstants.white,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            e.title ?? '',
                            style: TextStyle(
                              fontFamily: teachers,
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              height: 22 / 16,
                              color: e.isHighlighted
                                  ? ColorConstants.onyx
                                  : ColorConstants.white,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ))
        .toList();
  }
}
