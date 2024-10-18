import 'package:medito/repositories/path_repository.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../models/path/path_result.dart';

part 'path_notifier.g.dart';

@riverpod
class PathNotifier extends _$PathNotifier {
  @override
  AsyncValue<List<Step>> build() {
    fetchPathData();
    return const AsyncValue.loading();
  }

  Future<void> fetchPathData() async {
    state = const AsyncValue.loading();
    final result = await ref.read(pathRepositoryProvider).fetchPathData();
    _updateState(result);
  }

  Future<void> updateTaskCompletion(String taskId, bool isCompleted) async {
    final currentState = state;
    if (currentState is AsyncData<List<Step>>) {
      state = AsyncValue.data(_updateTaskInState(
        currentState.value,
        taskId,
        (task) => task.copyWith(isCompleted: isCompleted),
      ));
    }

    final result = await ref
        .read(pathRepositoryProvider)
        .updateTaskCompletion(taskId, isCompleted);
    _updateState(result);
  }

  Future<void> updateJournalEntry(
      String taskId, String entryText, bool markAsCompleted) async {
    final currentState = state;
    if (currentState is AsyncData<List<Step>>) {
      state = AsyncValue.data(_updateTaskInState(
        currentState.value,
        taskId,
        (task) => task.copyWith(
          isCompleted: markAsCompleted,
          data: JournalData(entryText: entryText),
        ),
      ));
    }

    final result = await ref
        .read(pathRepositoryProvider)
        .updateJournalEntry(taskId, entryText, markAsCompleted);
    _updateState(result);
  }

  List<Step> _updateTaskInState(
    List<Step> steps,
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

      // Check if all tasks in this step are completed
      bool allTasksCompleted =
          updatedStep.tasks.every((task) => task.isCompleted);
      updatedStep = updatedStep.copyWith(isCompleted: allTasksCompleted);

      return updatedStep;
    }).toList();

    // Unlock the next step if the current step is completed
    for (int i = 0; i < updatedSteps.length - 1; i++) {
      if (updatedSteps[i].isCompleted && !updatedSteps[i + 1].isUnlocked) {
        updatedSteps[i + 1] = updatedSteps[i + 1].copyWith(isUnlocked: true);
        break;
      }
    }

    return updatedSteps;
  }

  void _updateState(PathResult result) {
    state = switch (result) {
      PathResultSuccess(steps: var steps) => AsyncValue.data(steps),
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
