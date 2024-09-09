import 'package:medito/models/maintenance/maintenance_model.dart';
import 'package:medito/services/network/maintenance_dio_api_service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'maintenance_repository.g.dart';

abstract class MaintenanceRepository {
  Future<MaintenanceModel> fetchMaintenance();
}

class MaintenanceRepositoryImpl extends MaintenanceRepository {
  final MaintenanceDioApiService client;

  MaintenanceRepositoryImpl({required this.client});

  @override
  Future<MaintenanceModel> fetchMaintenance() async {
    try {
      var response = await client.getRequest();

      if (response == null) {
        return MaintenanceModel();
      }

      return MaintenanceModel.fromJson(response);
    } catch (e) {
      return MaintenanceModel();
    }
  }
}

@riverpod
MaintenanceRepositoryImpl maintenanceRepository(
  AutoDisposeProviderRef<MaintenanceRepositoryImpl> _,
) {
  return MaintenanceRepositoryImpl(client: MaintenanceDioApiService());
}
