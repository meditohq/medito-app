import 'package:Medito/repositories/repositories.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final playerProvider = ChangeNotifierProvider<PlayerViewModel>((ref) {
  return PlayerViewModel(ref);
});

class PlayerViewModel extends ChangeNotifier {
  ChangeNotifierProviderRef<PlayerViewModel> ref;
  PlayerViewModel(this.ref);
  double downloadingProgress = 0.0;

  Future<void> downloadSessionAudio(String url, {String? fileName}) async {
    try {
      final downloadAudio = ref.read(downloaderRepositoryProvider);
      await downloadAudio.downloadFile(
        url,
        name: fileName,
        onReceiveProgress: (received, total) {
          if (total != -1) {
            downloadingProgress = (received / total * 100);
            // (received / total * 100).toStringAsFixed(0) + '%';
            print(downloadingProgress);
            notifyListeners();
          }
        },
      );
    } catch (e) {
      rethrow;
    }
  }
}
