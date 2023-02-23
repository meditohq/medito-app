import 'package:Medito/models/models.dart';
import 'package:Medito/repositories/repositories.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
part 'background_sounds_viewmodel.g.dart';

@riverpod
Future<List<BackgroundSoundsModel>> backgroundSounds(BackgroundSoundsRef ref) {
  final backgroundSoundsRepository =
      ref.watch(backgroundSoundsRepositoryProvider);
  return backgroundSoundsRepository.fetchBackgroundSounds();
}

final backgroundSoundsNotifierProvider =
    ChangeNotifierProvider<BackgroundSoundsNotifier>((ref) {
  return BackgroundSoundsNotifier();
});

class BackgroundSoundsNotifier extends ChangeNotifier {
  double volume = 0;
  BackgroundSoundsModel? selectedBgSound;

  void handleOnChangeVolume(double _volume) {
    volume = _volume;
    notifyListeners();
  }

  void handleOnChangeSound(BackgroundSoundsModel _sound) {
    selectedBgSound = _sound;
    notifyListeners();
  }
}
