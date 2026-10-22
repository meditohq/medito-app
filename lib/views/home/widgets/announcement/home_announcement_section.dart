import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medito/models/home/announcement/announcement_model.dart';
import 'package:medito/providers/home/announcement_provider.dart';
import 'package:medito/views/home/widgets/announcement/announcement_widget.dart';
import 'package:medito/providers/donation/supporter_appeal_experiment.dart';
import 'package:medito/providers/donation/supporter_appeal_provider.dart';
import 'package:medito/providers/shared_preference/shared_preference_provider.dart';
import 'supporter_appeal_card.dart';

class HomeAnnouncementSection extends ConsumerWidget {
  const HomeAnnouncementSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appeal = ref.watch(supporterAppealProvider).value;
    final showAppeal =
        appeal != null &&
        SupporterAppealExperiment(
          ref.watch(sharedPreferencesProvider),
        ).showCard(DateTime.now());
    final data = ref.watch(fetchLatestAnnouncementProvider);

    final serverCard = data.when(
      loading: () => const SizedBox.shrink(),
      error: (err, stack) => const SizedBox.shrink(),
      data: (AnnouncementModel? announcement) {
        if (announcement == null ||
            announcement.text == null ||
            announcement.text == '' ||
            (showAppeal &&
                (announcement.ctaType == 'donation' ||
                    announcement.ctaPath == 'donation' ||
                    [
                      'donate.meditofoundation.org',
                      'paywall.meditofoundation.org',
                    ].contains(
                      Uri.tryParse(announcement.ctaPath ?? '')?.host,
                    )))) {
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
    return Column(
      children: [if (showAppeal) const SupporterAppealCard(), serverCard],
    );
  }
}
