import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:medito/constants/constants.dart';
import 'package:medito/routes/routes.dart';
import 'package:medito/views/home/widgets/header/home_header_widget.dart';
import 'package:medito/widgets/errors/medito_error_widget.dart';
import 'package:medito/widgets/headers/medito_app_bar_small.dart';
import 'package:medito/widgets/widgets.dart';
import '../../providers/pack/pack_provider.dart';
import '../../models/models.dart';

class JourneyView extends ConsumerStatefulWidget {
  const JourneyView({super.key});

  @override
  ConsumerState<JourneyView> createState() => _JourneyViewState();
}

class _JourneyViewState extends ConsumerState<JourneyView>
    with AutomaticKeepAliveClientMixin<JourneyView> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_scrollListener);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final pathState = ref.watch(packProvider(packId: 'rzU7Oy2fxijy4f9n'));

    return Scaffold(
      appBar: AppBar(
        centerTitle: false,
        backgroundColor: ColorConstants.ebony,
        title: const Column(
          children: [
            HomeHeaderWidget(
              greeting: StringConstants.path,
            ),
          ],
        ),
        elevation: 0.0,
      ),
      body: pathState.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => MeditoErrorWidget(
          message: 'Failed to load path: $error',
          onTap: () => ref.refresh(packProvider(packId: 'rzU7Oy2fxijy4f9n')),
        ),
        data: (pack) => _buildContent(pack),
      ),
    );
  }

  Widget _buildContent(PackModel pack) {
    return RefreshIndicator(
      onRefresh: () async => ref.refresh(packProvider(packId: 'path')),
      child: CustomScrollView(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final firstUncompletedIndex = pack.items.indexWhere(
                    (item) => !(item.isCompleted ?? false),
                  );

                  return _TrackItem(
                    item: pack.items[index],
                    index: index,
                    isFirstUncompleted: index == firstUncompletedIndex,
                  );
                },
                childCount: pack.items.length,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _scrollListener() => setState(() {});

  @override
  bool get wantKeepAlive => true;
}

class _TrackItem extends ConsumerWidget {
  final PackItemsModel item;
  final int index;
  final bool isFirstUncompleted;

  const _TrackItem({
    required this.item,
    required this.index,
    required this.isFirstUncompleted,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isCompleted = item.isCompleted ?? false;
    final backgroundColor = isCompleted
        ? ColorConstants.lightPurple
        : isFirstUncompleted
            ? ColorConstants.amber
            : Colors.grey[800];
    final textColor =
        isCompleted || isFirstUncompleted ? Colors.white : Colors.grey;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Card(
        color: backgroundColor,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: isFirstUncompleted
              ? const BorderSide(color: ColorConstants.white, width: 0.5)
              : BorderSide.none,
        ),
        child: ListTile(
          title: Text(
            item.title,
            style: TextStyle(
              color: textColor,
              fontWeight:
                  isFirstUncompleted ? FontWeight.bold : FontWeight.normal,
              fontSize: isFirstUncompleted ? 16 : 14,
            ),
          ),
          trailing: isCompleted
              ? HugeIcon(
                  icon: HugeIcons.strokeStandardTick02,
                  color: Colors.white,
                )
              : null,
          onTap: isCompleted || isFirstUncompleted
              ? () => handleNavigation('track', [item.id], context, ref: ref)
              : null,
        ),
      ),
    );
  }
}
