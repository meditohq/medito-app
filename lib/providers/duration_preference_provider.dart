import 'package:flutter_riverpod/flutter_riverpod.dart';

class DurationPreferenceNotifier extends Notifier<int?> {
  @override
  int? build() => null;

  void setDuration(int? duration) {
    if (duration != null) {
      state = duration;
    }
  }
}

final durationPreferenceProvider =
    NotifierProvider<DurationPreferenceNotifier, int?>(
  DurationPreferenceNotifier.new,
);
