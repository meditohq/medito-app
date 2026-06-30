import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medito/models/home/announcement/announcement_model.dart';
import 'package:medito/providers/home/announcement_provider.dart';
import 'package:medito/views/home/widgets/announcement/announcement_widget.dart';

class HomeAnnouncementSection extends ConsumerWidget {
  const HomeAnnouncementSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(fetchLatestAnnouncementProvider);

    return data.when(
      loading: () => const SizedBox.shrink(),
      error: (err, stack) => const SizedBox.shrink(),
      data: (AnnouncementModel? announcement) {
        if (announcement == null ||
            announcement.text == null ||
            announcement.text == '') {
          return const SizedBox.shrink();
        }

        return AnnouncementWidget(
          announcement: announcement,
          onPressedDismiss: () {
            ref
                .read(dismissedAnnouncementProvider.notifier)
                .dismissAnnouncement(announcement.id!);
          },
        );
      },
    );
  }
}
