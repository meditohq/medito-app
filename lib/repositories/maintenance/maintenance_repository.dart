import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medito/models/maintenance/maintenance_model.dart';
import 'package:medito/services/network/maintenance_api_service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'maintenance_repository.g.dart';

abstract class MaintenanceRepository {
  Future<MaintenanceModel> fetchMaintenance();
}

class MaintenanceRepositoryImpl extends MaintenanceRepository {

  MaintenanceRepositoryImpl({required this.client});

  @override
  Future<MaintenanceModel> fetchMaintenance() async {
    try {
      var response = await client.getRequest();

      if (response == null) {
        return const MaintenanceModel();
      }

      return MaintenanceModel.fromJson(response);
    } catch (e) {
      return const MaintenanceModel();
    }
  }
}

@riverpod
MaintenanceRepository maintenanceRepository(Ref _) {
  return MaintenanceRepositoryImpl(client: MaintenanceApiService());
}
