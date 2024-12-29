import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:medito/providers/stats_provider.dart';
import 'package:medito/routes/routes.dart';
import 'package:medito/views/track/track_view.dart';
import '../../controllers/path_notifier.dart';
import '../../models/path/path_result.dart' as result;
import '../../constants/strings/string_constants.dart';
import 'journal_entry_view.dart';

class JourneyView extends ConsumerWidget {
  const JourneyView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Sync updates when the view is loaded
    Future(() {
      ref.read(pathNotifierProvider.notifier).syncPendingUpdates();
    });

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
        data: (steps) => _buildStepsList(steps),
      ),
    );
  }

  Widget _buildStepsList(List<result.JourneyStep> steps) {
    return ListView.builder(
      itemCount: steps.length,
      itemBuilder: (context, index) {
        final step = steps[index];
        final isFirstLockedStep =
            step.isLocked && (index == 0 || !steps[index - 1].isLocked);
        return ExpansionTile(
          title: Text(_getStepTitle(step, isFirstLockedStep)),
          leading: _buildStepIcon(step),
          children: _buildStepChildren(step, isFirstLockedStep),
        );
      },
    );
  }

  String _getStepTitle(result.JourneyStep step, bool isFirstLockedStep) {
    if (!step.isLocked || isFirstLockedStep) {
      return '${StringConstants.stepTitle}: ${step.title}';
    } else {
      return '${StringConstants.stepTitle}: ...';
    }
  }

  Widget _buildStepIcon(result.JourneyStep step) {
    if (step.isCompleted) {
      return HugeIcon(
          icon: HugeIcons.solidSharpCheckmarkCircle02, color: Colors.green);
    } else if (step.isLocked) {
      return HugeIcon(
          icon: HugeIcons.solidRoundedSquareLock02, color: Colors.grey);
    } else {
      var allRequiredTasksCompleted = step.tasks
          .where((task) => task.isRequired)
          .every((task) => task.isCompleted);

      return HugeIcon(
        icon: allRequiredTasksCompleted 
            ? HugeIcons.solidSharpCheckmarkCircle02 
            : HugeIcons.strokeRoundedCircle,
        color: allRequiredTasksCompleted ? Colors.green : Colors.grey,
      );
    }
  }

  List<Widget> _buildStepChildren(
      result.JourneyStep step, bool isFirstLockedStep) {
    if (!step.isLocked || isFirstLockedStep) {
      return step.tasks
          .map((task) => TaskListTile(
                task: task,
                isEnabled: !step.isLocked,
              ))
          .toList();
    } else {
      return [const ListTile(title: Text('...'))];
    }
  }
}
class TaskListTile extends ConsumerWidget {
  final result.Task task;
  final bool isEnabled;

  const TaskListTile({
    super.key,
    required this.task,
    required this.isEnabled,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLoading = ref.watch(taskLoadingProvider(task.id));

    return ListTile(
      leading: _buildLeadingIcon(task),
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
          : _buildTaskIcon(task, ref),
      
      onTap: (isEnabled && !isLoading) ? () => _onTaskTap(context, ref) : null,
    );
  }

  Widget _buildTaskSubtitle(result.Task task) {
    const maxLength = 35;
    var subtitleText = switch (task.data) {
      result.TrackData(duration: var duration) =>
        '${StringConstants.duration}: $duration ${StringConstants.minutes}',
      result.JournalData(entryText: var entryText) =>
        entryText.length > maxLength
            ? '${entryText.substring(0, maxLength)}...'
            : entryText.isNotEmpty
                ? entryText
                : StringConstants.writeYourJournalEntryHere,
      result.ArticleData() =>
        StringConstants.tapToReadArticle.length > maxLength
            ? '${StringConstants.tapToReadArticle.substring(0, maxLength)}...'
            : StringConstants.tapToReadArticle,
    };

    return Text(
      subtitleText,
      style: TextStyle(
        color: isEnabled ? null : Colors.grey,
      ),
    );
  }

  Widget _buildTaskIcon(result.Task task, WidgetRef ref) {
    if (task.isCompleted) {
      return HugeIcon(
        icon: HugeIcons.solidSharpCheckmarkCircle02,
        color: Colors.green,
      );
    }

    return HugeIcon(
      icon: HugeIcons.strokeRoundedCircle,
      color: isEnabled ? Colors.white : Colors.grey,
    );
  }

  Widget _buildLeadingIcon(result.Task task) {
    var iconData = switch (task.type) {
      result.TaskType.journal => HugeIcons.strokeRoundedPenTool03,
      result.TaskType.track => HugeIcons.strokeRoundedHeadphones,
      result.TaskType.article => HugeIcons.strokeRoundedDoc01,
    };

    return HugeIcon(
      icon: iconData,
      color: isEnabled ? Colors.white : Colors.grey,
    );
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
      case result.TaskType.track:
        final trackData = task.data as result.TrackData;
        await handleNavigation('track', [trackData.id], context,
            ref: ref);
        break;
      case result.TaskType.article:
        // TODO: Implement article viewing logic
        break;
    }

    if (task.type == result.TaskType.article) {
      ref.read(taskLoadingProvider(task.id).notifier).setLoading(true);
      await ref.read(pathNotifierProvider.notifier).updateTaskCompletion(
            task.id,
            !task.isCompleted,
          );
      ref.read(taskLoadingProvider(task.id).notifier).setLoading(false);
    }
  }
}
