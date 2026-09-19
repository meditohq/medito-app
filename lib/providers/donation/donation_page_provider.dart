import 'package:medito/models/events/donation/donation_page_model.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../repositories/donation/donation_page_repository.dart';

part 'donation_page_provider.g.dart';

/// The end-screen donation ask.
///
/// Only a SUCCESSFUL fetch is kept alive for the rest of the process. Keeping
/// the provider alive before the fetch resolved used to pin a transient error
/// (typically an Android resume with the radio not yet back up) for every
/// later end screen in the same session, so one blip meant no ask until the
/// app was killed. A failed fetch now auto-disposes as soon as nothing watches
/// it, so the next end screen — or the widget's own retry — gets a fresh
/// attempt. The player also warms this provider at session start (see
/// player_view.dart) while the network is known to be up.
@riverpod
Future<DonationPageModel> fetchDonationPage(Ref ref) async {
  final donationPageRepository = ref.watch(donationPageRepositoryProvider);

  final page = await donationPageRepository.fetchDonationPage();
  ref.keepAlive();

  return page;
}
