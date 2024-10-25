import 'dart:convert';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/path/path_result.dart';
import '../models/path/path_dto.dart';
import '../mappers/path_mapper.dart';
import '../providers/shared_preference/shared_preference_provider.dart';

part 'path_repository.g.dart';

class PathRepository {
  final SharedPreferences _prefs;
  final PathMapper _pathMapper;

  PathRepository(this._prefs, this._pathMapper);

  static const String _cacheKey = 'path_data';

  Future<PathResult> fetchPathData() async {
    try {
      final response = await _fetchFromNetwork();
      final pathDto = PathDTO.fromJson(json.decode(response));
      await _cachePathData(response);
      return _pathMapper.mapDtoToResult(pathDto);
    } catch (e) {
      return PathResultError('Failed to fetch path data: ${e.toString()}');
    }
  }

  Future<PathResult> updateTaskCompletion(String taskId, bool isCompleted) async {
    try {
      final updatedResponse = await _updateTaskOnNetwork(taskId, isCompleted);
      final updatedPathDto = PathDTO.fromJson(json.decode(updatedResponse));
      return _pathMapper.mapDtoToResult(updatedPathDto);
    } catch (e) {
      return PathResultError('Failed to update task completion: ${e.toString()}');
    }
  }

  Future<PathResult> updateJournalEntry(String taskId, String entryText, bool markAsCompleted) async {
    try {
      final updatedResponse = await _updateJournalOnNetwork(taskId, entryText, markAsCompleted);
      final updatedPathDto = PathDTO.fromJson(json.decode(updatedResponse));
      await _cachePathData(updatedResponse);
      return _pathMapper.mapDtoToResult(updatedPathDto);
    } catch (e) {
      return PathResultError('Failed to update journal entry: ${e.toString()}');
    }
  }

  Future<String> _fetchFromNetwork() async {
    // In a real implementation, this would make an HTTP request
    await Future.delayed(const Duration(seconds: 1));
    return _getMockedJson();
  }

  Future<String> _updateTaskOnNetwork(String taskId, bool isCompleted) async {
    // In a real implementation, this would make an HTTP request
    await Future.delayed(const Duration(milliseconds: 500));
    
    final currentData = _prefs.getString(_cacheKey) ?? _getMockedJson();
    var pathDto = PathDTO.fromJson(json.decode(currentData));
    
    pathDto = pathDto.copyWith(
      steps: pathDto.steps.map((step) {
        var updatedStep = step.copyWith(
          tasks: step.tasks.map((task) {
            if (task.id == taskId) {
              return task.copyWith(
                isCompleted: isCompleted,
                lastUpdated: DateTime.now().millisecondsSinceEpoch,
              );
            }
            return task;
          }).toList(),
        );

        // Check if all tasks in this step are completed
        bool allTasksCompleted = updatedStep.tasks.every((task) => task.isCompleted);
        updatedStep = updatedStep.copyWith(isCompleted: allTasksCompleted);

        return updatedStep;
      }).toList(),
    );

    // Unlock the next step if the current step is completed
    for (int i = 0; i < pathDto.steps.length - 1; i++) {
      if (pathDto.steps[i].isCompleted && !pathDto.steps[i + 1].isUnlocked) {
        pathDto = pathDto.copyWith(
          steps: List.from(pathDto.steps)
            ..[i + 1] = pathDto.steps[i + 1].copyWith(isUnlocked: true),
        );
        break;
      }
    }

    // Save the updated data to SharedPreferences
    await _cachePathData(json.encode(pathDto.toJson()));

    return json.encode(pathDto.toJson());
  }

  Future<String> _updateJournalOnNetwork(String taskId, String entryText, bool markAsCompleted) async {
    // In a real implementation, this would make an HTTP request
    await Future.delayed(const Duration(milliseconds: 500));
    
    final currentData = _prefs.getString(_cacheKey) ?? _getMockedJson();
    var pathDto = PathDTO.fromJson(json.decode(currentData));
    
    pathDto = pathDto.copyWith(
      steps: pathDto.steps.map((step) {
        var updatedStep = step.copyWith(
          tasks: step.tasks.map((task) {
            if (task.id == taskId && task.type == 'journal') {
              return task.copyWith(
                data: {...task.data, 'entryText': entryText},
                lastUpdated: DateTime.now().millisecondsSinceEpoch,
                isCompleted: markAsCompleted,
              );
            }
            return task;
          }).toList(),
        );

        // Check if all tasks in this step are completed
        bool allTasksCompleted = updatedStep.tasks.every((task) => task.isCompleted);
        updatedStep = updatedStep.copyWith(isCompleted: allTasksCompleted);

        return updatedStep;
      }).toList(),
    );

    // Unlock the next step if the current step is completed
    for (int i = 0; i < pathDto.steps.length - 1; i++) {
      if (pathDto.steps[i].isCompleted && !pathDto.steps[i + 1].isUnlocked) {
        pathDto = pathDto.copyWith(
          steps: List.from(pathDto.steps)
            ..[i + 1] = pathDto.steps[i + 1].copyWith(isUnlocked: true),
        );
        break;
      }
    }

    // Save the updated data to SharedPreferences
    await _cachePathData(json.encode(pathDto.toJson()));

    return json.encode(pathDto.toJson());
  }

  Future<void> _cachePathData(String data) async {
    await _prefs.setString(_cacheKey, data);
  }

  String _getMockedJson() {
    // This method would be removed in the real implementation
    return '''
    {
      "steps": [
        {
          "id": "step1",
          "title": "Introduction",
          "isUnlocked": true,
          "tasks": [
            {
              "id": "task1",
              "type": "meditation",
              "title": "Welcome Meditation",
              "isCompleted": false,
              "lastUpdated": 0,
              "data": {
                "duration": 300
              }
            },
            {
              "id": "task2",
              "type": "journal",
              "title": "Reflect on Your Goals",
              "isCompleted": false,
              "lastUpdated": 0,
              "data": {
                "entryText": ""
              }
            }
          ]
        },
        {
          "id": "step2",
          "title": "Mindfulness Basics",
          "isUnlocked": false,
          "tasks": [
            {
              "id": "task3",
              "type": "article",
              "title": "Understanding Mindfulness",
              "isCompleted": false,
              "lastUpdated": 0,
              "data": {
                "content": "Mindfulness is the practice of being fully present and engaged in the moment..."
              }
            },
            {
              "id": "task4",
              "type": "meditation",
              "title": "5-Minute Breathing Exercise",
              "isCompleted": false,
              "lastUpdated": 0,
              "data": {
                "duration": 300
              }
            }
          ]
        },
        {
          "id": "step3",
          "title": "Deepening Your Practice",
          "isUnlocked": false,
          "tasks": [
            {
              "id": "task5",
              "type": "meditation",
              "title": "Body Scan Meditation",
              "isCompleted": false,
              "lastUpdated": 0,
              "data": {
                "duration": 600
              }
            },
            {
              "id": "task6",
              "type": "journal",
              "title": "Reflect on Your Experience",
              "isCompleted": false,
              "lastUpdated": 0,
              "data": {
                "entryText": ""
              }
            },
            {
              "id": "task7",
              "type": "article",
              "title": "The Science of Meditation",
              "isCompleted": false,
              "lastUpdated": 0,
              "data": {
                "content": "Recent studies have shown that regular meditation practice can lead to..."
              }
            }
          ]
        }
      ]
    }
    ''';
  }
}

@riverpod
PathRepository pathRepository(PathRepositoryRef ref) {
  final sharedPrefs = ref.watch(sharedPreferencesProvider);
  final pathMapper = ref.watch(pathMapperProvider);
  return PathRepository(sharedPrefs, pathMapper);
}

@riverpod
PathMapper pathMapper(PathMapperRef ref) => PathMapper();
