import 'package:flutter/foundation.dart';
import 'package:medito/providers/shared_preference/shared_preference_provider.dart';
import 'package:medito/repositories/path_repository.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../models/path/path_result.dart';
import '../services/task_update_service.dart';

part 'path_notifier.g.dart';

@riverpod
class PathNotifier extends _$PathNotifier {
  late final TaskUpdateService _taskUpdateService;

  @override
  AsyncValue<List<JourneyStep>> build() {
    _taskUpdateService = TaskUpdateService(ref.read(sharedPreferencesProvider));
    fetchPathData();
    return const AsyncValue.loading();
  }

  Future<void> fetchPathData() async {
    state = const AsyncValue.loading();
    final result = await ref.read(pathRepositoryProvider).fetchPathData();
    _updateState(result);
  }

  Future<void> syncPendingUpdates() async {
    final updates = _taskUpdateService.getPendingUpdates();
    if (updates.isEmpty) return;

    final payload = TaskUpdatePayload(
      updated: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      tasks: updates,
    );

    try {
      await ref.read(pathRepositoryProvider).updateTaskProgress('1', payload);
      await _taskUpdateService.clearUpdates();
      // Refresh path data to get the latest state from server
      await fetchPathData();
    } catch (e) {
      debugPrint('Failed to sync updates: $e');
    }
  }

  Future<void> updateTaskCompletion(String taskId, bool isCompleted) async {
    final currentState = state.value;
    if (currentState == null) return;

    var stepId = '';
    for (final step in currentState) {
      if (step.tasks.any((t) => t.id == taskId)) {
        stepId = step.id;
        break;
      }
    }

    final update = TaskUpdate(
      stepId: stepId,
      taskId: taskId,
      completedAt: [DateTime.now().millisecondsSinceEpoch ~/ 1000],
    );

    await _taskUpdateService.addUpdate(update);

    // Update local state immediately
    state = AsyncData(currentState.map((step) {
      return step.copyWith(
        tasks: step.tasks.map((task) {
          if (task.id == taskId) {
            return task.copyWith(isCompleted: isCompleted);
          }
          return task;
        }).toList(),
      );
    }).toList());
  }

  Future<void> updateJournalEntry(
      String taskId, String entryText, bool markAsCompleted) async {
    final currentState = state;
    if (currentState is AsyncData<List<JourneyStep>>) {
      state = AsyncValue.data(_updateTaskInState(
        currentState.value,
        taskId,
        (task) => task.copyWith(
          isCompleted: markAsCompleted,
          data: JournalData(id: 'wow', entryText: entryText),
        ),
      ));
    }

    final result = await ref
        .read(pathRepositoryProvider)
        .updateJournalEntry(taskId, entryText, markAsCompleted);
    _updateState(result);
  }

  List<JourneyStep> _updateTaskInState(
    List<JourneyStep> steps,
    String taskId,
    Task Function(Task) updateFunction,
  ) {
    var updatedSteps = steps.map((step) {
      var updatedStep = step.copyWith(
        tasks: step.tasks.map((task) {
          if (task.id == taskId) {
            return updateFunction(task);
          }
          return task;
        }).toList(),
      );

      // Check if all required tasks in this step are completed
      bool allRequiredTasksCompleted = updatedStep.tasks
          .where((task) => task.isRequired)
          .every((task) => task.isCompleted);
      updatedStep =
          updatedStep.copyWith(isCompleted: allRequiredTasksCompleted);

      return updatedStep;
    }).toList();

    // Unlock the next step if the current step is completed
    for (int i = 0; i < updatedSteps.length - 1; i++) {
      if (updatedSteps[i].isCompleted && updatedSteps[i + 1].isLocked) {
        updatedSteps[i + 1] = updatedSteps[i + 1].copyWith(isLocked: false);
        break;
      }
    }

    return updatedSteps;
  }

  void _updateState(JourneyResult result) {
    state = switch (result) {
      JourneyResultSuccess(steps: var steps) => AsyncValue.data(steps),
      PathResultError(message: var errorMessage) =>
        AsyncValue.error(errorMessage, StackTrace.current),
    };
  }
}

@riverpod
class TaskLoading extends _$TaskLoading {
  @override
  bool build(String taskId) => false;

  void setLoading(bool isLoading) {
    state = isLoading;
  }
}
