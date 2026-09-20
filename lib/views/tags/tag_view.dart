import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medito/constants/constants.dart';
import 'package:medito/exceptions/app_error.dart';
import 'package:medito/l10n/app_localizations.dart';
import 'package:medito/models/tags/tag_model.dart';
import 'package:medito/providers/tags/tags_provider.dart';
import 'package:medito/services/analytics/firebase_analytics_service.dart';
import 'package:medito/utils/tag_labels.dart';
import 'package:medito/views/explore/widgets/track_list_sliver.dart';
import 'package:medito/widgets/headers/medito_app_bar_small.dart';
import 'package:medito/widgets/widgets.dart';

/// Every track carrying one tag, strongest match first.
class TagView extends ConsumerStatefulWidget {
  const TagView({super.key, required this.tag});

  final TagModel tag;

  @override
  ConsumerState<TagView> createState() => _TagViewState();
}

class _TagViewState extends ConsumerState<TagView> {
  @override
  void initState() {
    super.initState();
    FirebaseAnalyticsService().logEvent(
      name: 'tag_opened',
      parameters: {'tag_id': widget.tag.id, 'tag_group': widget.tag.group},
    );
  }

  @override
  Widget build(BuildContext context) {
    final tracksAsync = ref.watch(tagTracksProvider(widget.tag.id));

    return Scaffold(
      appBar: MeditoAppBarSmall(
        title: tagLabel(context, widget.tag.id),
        hasBackButton: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
      body: tracksAsync.when(
        data: (tracks) {
          if (tracks.isEmpty) {
            return Center(
              child: Text(
                AppLocalizations.of(context)!.tagNoTracks,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            );
          }
          return CustomScrollView(
            slivers: [
              TrackListSliver(tracks: tracks),
              SliverPadding(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.paddingOf(context).bottom + padding16,
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => MeditoErrorWidget(
          error: err is AppError ? err : const UnknownError(),
          isScaffold: false,
          onTap: () => ref.invalidate(tagTracksProvider(widget.tag.id)),
        ),
      ),
    );
  }
}
