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
              title: Text(_getStepTitle(step, index)),
              leading: _buildStepIcon(step),
              children: _buildStepChildren(step, index),
            );
          },
        ),
      ),
    );
  }

  String _getStepTitle(result.Step step, int index) {
    if (step.isUnlocked) {
      return '${StringConstants.stepTitle} ${index + 1}: ${step.title}';
    } else if (index == 0) {
      return '${StringConstants.stepTitle} ${index + 1}: ${step.title} (${StringConstants.locked})';
    } else {
      return '${StringConstants.stepTitle} ${index + 1}: ${StringConstants.lockedStep}';
    }
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

  List<Widget> _buildStepChildren(result.Step step, int index) {
    if (step.isUnlocked) {
      return step.tasks
          .map((task) => TaskListTile(
                task: task,
                isEnabled: true,
              ))
          .toList();
    } else if (index == 0) {
      return step.tasks
          .map((task) => TaskListTile(
                task: task,
                isEnabled: false,
              ))
          .toList();
    } else {
      return [const ListTile(title: Text(StringConstants.stepLocked))];
    }
  }
}

class TaskListTile extends ConsumerWidget {
  final result.Task task;
  final bool isEnabled;

  const TaskListTile({
    Key? key,
    required this.task,
    required this.isEnabled,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLoading = ref.watch(taskLoadingProvider(task.id));

    return ListTile(
      title: Text(
        task.title,
        style: TextStyle(
          color: isEnabled ? null : Colors.grey,
        ),
      ),
      subtitle: _buildTaskSubtitle(task),
      trailing: isLoading
          ? const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : _buildTaskIcon(task),
      onTap: (isEnabled && !isLoading) ? () => _onTaskTap(context, ref) : null,
    );
  }

  Widget _buildTaskSubtitle(result.Task task) {
    var subtitleText = switch (task.data) {
      result.MeditationData(duration: var duration) =>
        '${StringConstants.duration}: $duration ${StringConstants.minutes}',
      result.JournalData(entryText: var entryText) => entryText.isNotEmpty
          ? StringConstants.journalEntrySaved
          : StringConstants.writeYourJournalEntryHere,
      result.ArticleData() => StringConstants.tapToReadArticle,
    };

    return Text(
      subtitleText,
      style: TextStyle(
        color: isEnabled ? null : Colors.grey,
      ),
    );
  }

  Widget _buildTaskIcon(result.Task task) {
    if (task.isCompleted) {
      return const Icon(Icons.check_circle, color: Colors.green);
    } else {
      return Icon(
        Icons.circle_outlined,
        color: isEnabled ? null : Colors.grey,
      );
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
