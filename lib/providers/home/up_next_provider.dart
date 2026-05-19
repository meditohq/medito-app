import 'package:medito/constants/config_constants.dart';
import 'package:medito/constants/strings/shared_preference_constants.dart';
import 'package:medito/models/models.dart';
import 'package:medito/providers/providers.dart';
import 'package:medito/repositories/repositories.dart';
import 'package:medito/providers/stats_provider.dart';
import 'package:medito/services/home_widget_service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'up_next_provider.g.dart';

@riverpod
String upNextPackId(Ref ref) {
  final prefs = ref.read(sharedPreferencesProvider);
  return prefs.getString(SharedPreferenceConstants.upNextPackId) ??
      ConfigConstants.basicsPackId;
}

class UpNextData {
  final PackModel pack;
  final PackItemsModel? nextSession;
  final int completedCount;
  final int totalCount;

  const UpNextData({
    required this.pack,
    required this.nextSession,
    required this.completedCount,
    required this.totalCount,
  });

  double get progressPercentage =>
      totalCount > 0 ? (completedCount / totalCount) * 100 : 0;

  bool get isCompleted => completedCount >= totalCount;
}

@Riverpod(keepAlive: true)
class UpNext extends _$UpNext {
  @override
  Future<UpNextData> build() => _load();

  Future<UpNextData> _load() async {
    final packRepository = ref.read(packRepositoryProvider);
    final prefs = ref.read(sharedPreferencesProvider);
    final statsManager = ref.read(statsManagerProvider);
    if (!statsManager.isInitialized) {
      await statsManager.initialize();
    }

    var packId = ref.read(upNextPackIdProvider);
    final isDefaultPack = packId == ConfigConstants.basicsPackId;
    var pack = await packRepository.fetchPacks(packId);
    var localStats = await statsManager.localAllStats;
    var tracksChecked = localStats.tracksChecked ?? [];

    var updatedItems = pack.items.map((item) {
      return item.copyWith(isCompleted: tracksChecked.contains(item.id));
    }).toList();

    var updatedPack = pack.copyWith(items: updatedItems);
    var completedCount =
        updatedItems.where((item) => item.isCompleted == true).length;
    final isCompleted = completedCount >= updatedItems.length;

    // If pack is completed and not default, switch back to default
    if (isCompleted && !isDefaultPack) {
      await prefs.remove(SharedPreferenceConstants.upNextPackId);
      packId = ConfigConstants.basicsPackId;
      pack = await packRepository.fetchPacks(packId);
      localStats = await statsManager.localAllStats;
      tracksChecked = localStats.tracksChecked ?? [];
      updatedItems = pack.items.map((item) {
        return item.copyWith(isCompleted: tracksChecked.contains(item.id));
      }).toList();
      updatedPack = pack.copyWith(items: updatedItems);
      completedCount =
          updatedItems.where((item) => item.isCompleted == true).length;
    }

    final currentPackCompleted = completedCount >= updatedItems.length;

    PackItemsModel? nextSession;
    if (currentPackCompleted && packId == ConfigConstants.basicsPackId) {
      nextSession = null;
    } else {
      nextSession = updatedItems.firstWhere(
        (item) => item.isCompleted != true,
        orElse: () => updatedItems.first,
      );
    }

    final upNextData = UpNextData(
      pack: updatedPack,
      nextSession: nextSession,
      completedCount: completedCount,
      totalCount: updatedItems.length,
    );

    if (nextSession != null) {
      HomeWidgetService.updateUpNextWidget(
        title: nextSession.title,
        packTitle: updatedPack.title,
        trackId: nextSession.id,
        subtitle: nextSession.subtitle,
        completed: completedCount,
        total: updatedItems.length,
      ).ignore();
    }

    return upNextData;
  }

  Future<void> refresh() async {
    state = await AsyncValue.guard(_load);
  }
}
