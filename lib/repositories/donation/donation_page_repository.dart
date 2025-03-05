import 'package:medito/models/events/donation/donation_page_model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medito/exceptions/app_error.dart';
import 'package:medito/services/network/http_api_service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../constants/http/http_constants.dart';

part 'donation_page_repository.g.dart';

abstract class DonationPageRepository {
  Future<DonationPageModel> fetchDonationPage();
}

class DonationPageRepositoryImpl implements DonationPageRepository {
  final Ref ref;
  final HttpApiService client;

  DonationPageRepositoryImpl({required this.ref, required this.client});

  @override
  Future<DonationPageModel> fetchDonationPage() async {
    try {
      final response = await client.getRequest(HTTPConstants.donate);
      return DonationPageModel.fromJson(response);
    } catch (error) {
      if (error is AppError) {
        rethrow;
      }
      throw const ServerError();
    }
  }
}

@riverpod
DonationPageRepository donationPageRepository(Ref ref) {
  return DonationPageRepositoryImpl(ref: ref, client: HttpApiService());
}
