import 'package:Medito/constants/constants.dart';
import 'package:Medito/routes/routes.dart';
import 'package:Medito/utils/utils.dart';
import 'package:Medito/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:Medito/providers/providers.dart';
import 'search_result_card_widget.dart';

class SearchResultWidget extends ConsumerWidget {
  const SearchResultWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var searchResult = ref.watch(searchProvider);
    final currentlyPlayingSession = ref.watch(playerProvider);
    var listViewPadding = EdgeInsets.only(
      top: 20,
      bottom: currentlyPlayingSession != null ? 0 : 60,
      left: 15,
      right: 15,
    );

    return searchResult.when(
      data: (data) {
        return GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
          child: ListView.builder(
            padding: listViewPadding,
            itemBuilder: (BuildContext context, int index) {
              var element = data[index];

              return SearchResultCardWidget(
                title: element.category,
                description: element.title,
                coverUrlPath: element.coverUrl,
                onTap: () =>
                    _handleTap(context, element.id, element.type, element.path),
              );
            },
            itemCount: data.length,
          ),
        );
      },
      error: (err, stack) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 20),
        child: Text(
          err.toString(),
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                letterSpacing: 0,
                color: ColorConstants.walterWhite,
                fontSize: 14,
              ),
        ),
      ),
      loading: () => const SearchResultShimmerWidget(),
    );
  }

  void _handleTap(
    BuildContext context,
    String id,
    String type,
    String path,
  ) {
    checkConnectivity().then((value) {
      if (value) {
        context.push(
          getPathFromString(
            type,
            [id.toString()],
          ),
          extra: {'url': path},
        );
      } else {
        createSnackBar(StringConstants.checkConnection, context);
      }
    });
  }
}
