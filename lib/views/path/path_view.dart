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
                (context, index) => _TrackItem(item: pack.items[index]),
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

  const _TrackItem({required this.item});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      children: [
        ListTile(
          leading: HugeIcon(
            icon: HugeIcons.strokeRoundedHeadphones,
            color: ColorConstants.white,
          ),
          title: Text(item.title),
          trailing: item.isCompleted ?? false
              ? HugeIcon(
                  icon: HugeIcons.solidSharpCheckmarkCircle02,
                  color: Colors.green,
                )
              : null,
          onTap: () => handleNavigation('track', [item.id], context, ref: ref),
        ),
        const Divider(height: 1, color: Colors.grey),
      ],
    );
  }
}
