
import 'package:medito/models/events/donation/donation_page_model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../constants/http/http_constants.dart';
import '../../services/network/dio_api_service.dart';

part 'donation_page_repository.g.dart';

abstract class DonationPageRepository {
  Future<DonationPageModel> fetchDonationPage();
}

class DonationPageRepositoryImpl extends DonationPageRepository {
  final DioApiService client;
  final Ref ref;

  DonationPageRepositoryImpl({required this.ref, required this.client});

  @override
  Future<DonationPageModel> fetchDonationPage() async {
    return client.getRequest(HTTPConstants.DONATE).then((response) {
      return DonationPageModel.fromJson(response);
    });
  }
}

@riverpod
DonationPageRepositoryImpl donationPageRepository(DonationPageRepositoryRef ref) {
  return DonationPageRepositoryImpl(ref: ref, client: DioApiService());
}
