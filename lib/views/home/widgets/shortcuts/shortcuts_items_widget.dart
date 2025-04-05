// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medito/constants/constants.dart';
import 'package:medito/models/models.dart';
import 'package:medito/providers/providers.dart';
import 'package:medito/routes/routes.dart';
import 'package:medito/utils/utils.dart';
import 'package:reorderables/reorderables.dart';
import 'package:medito/services/tiktok_events_service.dart';

import '../../../../providers/home/home_provider.dart';
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

  @override
  void didChangeDependencies() {
    data = widget.data;
    super.didChangeDependencies();
  }

  void _handleChipPress(
    BuildContext context,
    WidgetRef ref,
    ShortcutsModel element,
  ) async {
    await ref.read(tiktokEventsServiceProvider).logShortcutTap(
          shortcutId: element.id ?? 'unknown',
          shortcutTitle: element.title ?? 'unknown',
          shortcutType: element.type,
          shortcutPath: element.path ?? 'unknown',
        );

    await handleNavigation(
      element.type,
      [element.path.toString().getIdFromPath()],
      context,
      ref: ref,
    );
  }

  void _onReorder(int oldIndex, int newIndex) {
    setState(() {
      final element = data.removeAt(oldIndex);
      data.insert(newIndex, element);
      _handleShortcutItemPlacementInPreference(oldIndex, newIndex);
    });
  }

  Future<void> _handleShortcutItemPlacementInPreference(
    int oldIndex,
    int newIndex,
  ) async {
    var ids = data.map((e) => e.id).whereType<String>().toList();
    await ref.read(updateShortcutsIdsInPreferenceProvider(ids: ids).future);
    await ref.read(refreshHomeAPIsProvider.future);
  }

  @override
  Widget build(BuildContext context) {
    var size = MediaQuery.of(context).size;
    var isWideScreen = size.width > 600;
    const containerHeight = 48.0;
    final containerWidth =
        (size.width / (isWideScreen ? 3 : 2)) - (isWideScreen ? 16 : 19);

    return ReorderableWrap(
      spacing: 8.0,
      runSpacing: 8.0,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      maxMainAxisCount: isWideScreen ? 3 : 2,
      minMainAxisCount: isWideScreen ? 3 : 2,
      onReorder: _onReorder,
      children: data
          .map((e) => _buildShortcutItem(e, containerWidth, containerHeight))
          .toList(),
    );
  }

  Widget _buildShortcutItem(ShortcutsModel e, double width, double height) {
    return SizedBox(
      key: ValueKey(e.id),
      width: width,
      height: height,
      child: ElevatedButton(
        onPressed: () => _handleChipPress(context, ref, e),
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.all(12),
          backgroundColor:
              e.isHighlighted ? ColorConstants.brightSky : ColorConstants.onyx,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: Row(
          children: [
            MeditoHugeIcon(
              icon: e.icon ?? '',
              size: 18,
              color:
                  e.isHighlighted ? ColorConstants.onyx : ColorConstants.white,
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
    );
  }
}
