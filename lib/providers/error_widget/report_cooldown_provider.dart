import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'report_cooldown_provider.g.dart';

@riverpod
class ReportCooldown extends _$ReportCooldown {
  @override
  DateTime? build() {
    return null;
  }

  void startCooldown() {
    state = DateTime.now();
  }

  bool get isCoolingDown {
    if (state == null) return false;

    return DateTime.now().difference(state!) < const Duration(minutes: 1);
  }
}

@riverpod
bool isCoolingDown(Ref ref) {
  final cooldownStartTime = ref.watch(reportCooldownProvider);
  if (cooldownStartTime == null) return false;

  return DateTime.now().difference(cooldownStartTime) <
      const Duration(minutes: 1);
}
