import 'dart:io';

import 'package:Medito/constants/constants.dart';
import 'package:Medito/services/network/dio_api_service.dart';
import 'package:Medito/services/network/dio_client_provider.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'downloader_repository.g.dart';

abstract class DownloaderRepository {
  Future<void> downloadFile(
    String url, {
    String? name,
    void Function(int, int)? onReceiveProgress,
  });
  Future<String?> getDownloadedFile(String name);
  Future<void> deleteDownloadedFile(String name);
}

class DownloaderRepositoryImpl extends DownloaderRepository {
  DioApiService client;

  DownloaderRepositoryImpl({required this.client});

  @override
  Future<void> downloadFile(
    String url, {
    String? name,
    void Function(int, int)? onReceiveProgress,
  }) async {
    try {
      var file = await getApplicationDocumentsDirectory();
      var fileName = name != null
          ? name + '.' + url.substring(url.lastIndexOf('.') + 1)
          : url.substring(url.lastIndexOf('/') + 1);
      var savePath = file.path + '/' + fileName;
      print(savePath);
      var isExists = await File(savePath).exists();
      if (!isExists) {
        await client.dio.download(
          url,
          savePath,
          options: Options(headers: {
            HttpHeaders.acceptEncodingHeader: '*',
            HttpHeaders.authorizationHeader: HTTPConstants.CONTENT_TOKEN,
          }),
          onReceiveProgress: onReceiveProgress,
        );
      } else {
        throw ('File already exists');
      }
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<void> deleteDownloadedFile(
    String fileName,
  ) async {
    try {
      var file = await getApplicationDocumentsDirectory();
      var savePath = file.path + '/' + fileName;
      var filePath = File(savePath);
      var checkIsExists = await filePath.exists();
      if (checkIsExists) {
        await filePath.delete();
      }
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<String?> getDownloadedFile(String name) async {
    if (kIsWeb) return null;
    try {
      var file = await getApplicationDocumentsDirectory();
      var savePath = file.path + '/' + name;
      var filePath = File(savePath);
      
      return await filePath.exists() ? filePath.path : null;
    } catch (e) {
      rethrow;
    }
  }
}

@riverpod
DownloaderRepositoryImpl downloaderRepository(ref) {
  return DownloaderRepositoryImpl(client: ref.watch(dioClientProvider));
}
