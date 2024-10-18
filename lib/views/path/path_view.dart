import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../controllers/path_notifier.dart';
import '../../models/path/path_result.dart' as result;
import '../../constants/strings/string_constants.dart';
import 'journal_entry_view.dart';

class PathView extends ConsumerWidget {
  const PathView({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pathState = ref.watch(pathNotifierProvider);

    return Scaffold(
      appBar: AppBar(title: const Text(StringConstants.path)),
      body: pathState.when(
        loading: () => const Center(child: Text(StringConstants.loadingPath)),
        error: (error, stackTrace) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('${StringConstants.pathLoadError}: $error'),
              ElevatedButton(
                onPressed: () =>
                    ref.read(pathNotifierProvider.notifier).fetchPathData(),
                child: const Text(StringConstants.retry),
              ),
            ],
          ),
        ),
        data: (steps) => ListView.builder(
          itemCount: steps.length,
          itemBuilder: (context, index) {
            final step = steps[index];
            return ExpansionTile(
              title: Text(
                  '${StringConstants.stepTitle} ${index + 1}: ${step.title}'),
              leading: _buildStepIcon(step),
              children: step.isUnlocked
                  ? step.tasks.map((task) => TaskListTile(task: task)).toList()
                  : [const ListTile(title: Text(StringConstants.stepLocked))],
            );
          },
        ),
      ),
    );
  }

  Widget _buildStepIcon(result.Step step) {
    if (step.isCompleted) {
      return const Icon(Icons.check_circle, color: Colors.green);
    } else if (!step.isUnlocked) {
      return const Icon(Icons.lock, color: Colors.grey);
    } else {
      return const Icon(Icons.circle_outlined, color: Colors.grey);
    }
  }
}

class TaskListTile extends ConsumerWidget {
  final result.Task task;

  const TaskListTile({Key? key, required this.task}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLoading = ref.watch(taskLoadingProvider(task.id));

    return ListTile(
      title: Text(task.title),
      subtitle: _buildTaskSubtitle(task),
      trailing: isLoading
          ? const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : _buildTaskIcon(task),
      onTap: isLoading ? null : () => _onTaskTap(context, ref),
    );
  }

  Widget _buildTaskSubtitle(result.Task task) {
    return switch (task.data) {
      result.MeditationData(duration: var duration) => Text(
          '${StringConstants.duration}: $duration ${StringConstants.minutes}'),
      result.JournalData(entryText: var entryText) => Text(entryText.isNotEmpty
          ? StringConstants.journalEntrySaved
          : StringConstants.writeYourJournalEntryHere),
      result.ArticleData() => const Text(StringConstants.tapToReadArticle),
    };
  }

  Widget _buildTaskIcon(result.Task task) {
    if (task.isCompleted) {
      return const Icon(Icons.check_circle, color: Colors.green);
    } else {
      return const Icon(Icons.circle_outlined);
    }
  }

  void _onTaskTap(BuildContext context, WidgetRef ref) async {
    switch (task.type) {
      case result.TaskType.journal:
        final journalData = task.data as result.JournalData;
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => JournalEntryView(
              taskId: task.id,
              isCompleted: task.isCompleted,
              initialText: journalData.entryText,
            ),
          ),
        );
        break;
      case result.TaskType.meditation:
        // TODO: Implement meditation session logic
        break;
      case result.TaskType.article:
        // TODO: Implement article viewing logic
        break;
    }

    if (task.type != result.TaskType.journal) {
      ref.read(taskLoadingProvider(task.id).notifier).setLoading(true);
      await ref.read(pathNotifierProvider.notifier).updateTaskCompletion(
            task.id,
            !task.isCompleted,
          );
      ref.read(taskLoadingProvider(task.id).notifier).setLoading(false);
    }
  }
}
