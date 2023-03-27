import 'dart:io';

import 'package:Medito/constants/constants.dart';
import 'package:Medito/services/network/dio_api_services.dart';
import 'package:Medito/services/network/dio_client_provider.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
part 'downloader_repository.g.dart';

abstract class DownloaderRepository {
  Future<dynamic> downloadFile(String url,
      {String? name, void Function(int, int)? onReceiveProgress});
  Future<dynamic> getDownloadedFile(String name);
}

class DownloaderRepositoryImpl extends DownloaderRepository {
  DioApiService client;
  DownloaderRepositoryImpl({required this.client});

  @override
  Future downloadFile(String url,
      {String? name, void Function(int, int)? onReceiveProgress}) async {
    try {
      var file = await getApplicationDocumentsDirectory();
      var fileName = name ?? url.substring(url.lastIndexOf('/') + 1);
      var savePath = file.path + '/' + fileName;
      print(savePath);
      var isExists = await File(savePath).exists();
      if (!isExists) {
        await client.dio.download(url, savePath,
            options: Options(headers: {
              HttpHeaders.acceptEncodingHeader: '*',
              HttpHeaders.authorizationHeader: HTTPConstants.CONTENT_TOKEN
            }),
            onReceiveProgress: onReceiveProgress);
      } else {
        throw ('File already exists');
      }
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future getDownloadedFile(String name) {
    // TODO: implement getSessionAudio
    throw UnimplementedError();
  }
}

@riverpod
DownloaderRepositoryImpl downloaderRepository(DownloaderRepositoryRef ref) {
  return DownloaderRepositoryImpl(client: ref.watch(dioClientProvider));
}
