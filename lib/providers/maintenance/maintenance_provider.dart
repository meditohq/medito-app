import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../models/maintenance/maintenance_model.dart';
import '../../repositories/maintenance/maintenance_repository.dart';

part 'maintenance_provider.g.dart';

@riverpod
Future<MaintenanceModel> fetchMaintenance(FetchMaintenanceRef ref) {
  final maintenanceRepository = ref.watch(maintenanceRepositoryProvider);
  ref.keepAlive();

  return maintenanceRepository.fetchMaintenance();
}
