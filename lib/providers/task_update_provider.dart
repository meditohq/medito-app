import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/path/path_result.dart';

class TaskUpdateNotifier extends Notifier<List<TaskUpdate>> {
  @override
  List<TaskUpdate> build() => [];

  void addUpdate(TaskUpdate update) {
    state = [...state, update];
  }

  void clearUpdates() {
    state = [];
  }
}

final taskUpdateProvider =
    NotifierProvider<TaskUpdateNotifier, List<TaskUpdate>>(
      TaskUpdateNotifier.new,
    );
