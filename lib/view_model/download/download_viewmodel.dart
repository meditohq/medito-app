import 'dart:io';

import 'package:Medito/audioplayer/player_utils.dart';
import 'package:Medito/services/network/dio_api_services.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

final downloaderProvider = ChangeNotifierProvider<DownloadViewModel>((ref) {
  return DownloadViewModel();
});

class DownloadViewModel extends ChangeNotifier {
  String downloadingProgress = '';

  Future<void> downloadFile(DioApiService client, String url) async {
    try {
      var file = await getApplicationDocumentsDirectory();
      var fileName = url.substring(url.lastIndexOf('/') + 1);
      var savePath = file.path + '/' + fileName;
      print(savePath);
      var isExists = await File(savePath).exists();
      if (!isExists) {
        await client.dio.download(
          url,
          savePath,
          // options: Options(headers: {HttpHeaders.acceptEncodingHeader: '*'}),
          onReceiveProgress: (received, total) {
            if (total != -1) {
              downloadingProgress =
                  (received / total * 100).toStringAsFixed(0) + '%';
              print(downloadingProgress);
              notifyListeners();
            }
          },
        );
      } else {
        throw ('File already exists');
      }
    } catch (e) {
      downloadingProgress = '';
      print(e);
      rethrow;
    }
  }
}
