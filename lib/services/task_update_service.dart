import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/path/path_result.dart';

class TaskUpdateService {
  static const _taskUpdatesKey = 'pending_task_updates';
  final SharedPreferences _prefs;

  TaskUpdateService(this._prefs);

  List<TaskUpdate> getPendingUpdates() {
    final jsonString = _prefs.getString(_taskUpdatesKey);
    if (jsonString == null) return [];

    try {
      final jsonList = json.decode(jsonString) as List;
      return jsonList.map((json) => _taskUpdateFromJson(json)).toList();
    } catch (e) {
      print('Error decoding task updates: $e');
      return [];
    }
  }

  Future<void> addUpdate(TaskUpdate update) async {
    var updates = getPendingUpdates();
    updates.add(update);
    await _savePendingUpdates(updates);
  }

  Future<void> clearUpdates() async {
    await _prefs.remove(_taskUpdatesKey);
  }

  Future<void> _savePendingUpdates(List<TaskUpdate> updates) async {
    final jsonList = updates.map((update) => _taskUpdateToJson(update)).toList();
    await _prefs.setString(_taskUpdatesKey, json.encode(jsonList));
  }

  Map<String, dynamic> _taskUpdateToJson(TaskUpdate update) => {
        'step_id': update.stepId,
        'task_id': update.taskId,
        'completed_at': update.completedAt,
        'data': update.data,
      };

  TaskUpdate _taskUpdateFromJson(Map<String, dynamic> json) => TaskUpdate(
        stepId: json['step_id'] as String,
        taskId: json['task_id'] as String,
        completedAt: (json['completed_at'] as List).cast<int>(),
        data: json['data'] as Map<String, dynamic>,
      );
} 