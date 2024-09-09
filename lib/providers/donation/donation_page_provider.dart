import 'package:medito/models/events/donation/donation_page_model.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../repositories/donation/donation_page_repository.dart';

part 'donation_page_provider.g.dart';

@riverpod
Future<DonationPageModel> fetchDonationPage(
  FetchDonationPageRef ref,
) {
  final donationPageRepository = ref.watch(donationPageRepositoryProvider);
  ref.keepAlive();

  return donationPageRepository.fetchDonationPage();
}
