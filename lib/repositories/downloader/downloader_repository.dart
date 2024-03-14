import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:Medito/constants/strings/shared_preference_constants.dart';
import 'package:Medito/providers/providers.dart';
import 'package:Medito/services/network/dio_api_service.dart';
import 'package:Medito/utils/utils.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

part 'downloader_repository.g.dart';

abstract class DownloaderRepository {
  Future<void> downloadFile(
    String url, {
    required String name,
    void Function(int, int)? onReceiveProgress,
  });

  Future<String?> getDownloadedFile(String name);

  Future<void> deleteDownloadedFile(String name);

}

class DownloaderRepositoryImpl extends DownloaderRepository {
  DioApiService client;
  Ref ref;

  DownloaderRepositoryImpl({required this.client, required this.ref});

  @override
  Future<void> downloadFile(
    String url, {
    required String name,
    void Function(int, int)? onReceiveProgress,
  }) async {
    var file = await getApplicationDocumentsDirectory();
    var savePath = file.path + '/' + name;
    var isExists = await File(savePath).exists();
    if (!isExists) {
      await client.dio.download(
        url,
        savePath,
        options: Options(headers: {
          HttpHeaders.acceptEncodingHeader: '*',
        }),
        onReceiveProgress: onReceiveProgress,
      );
    } else {
      throw ('File already exists');
    }
  }

  @override
  Future<void> deleteDownloadedFile(
    String fileName,
  ) async {
    var file = await getApplicationDocumentsDirectory();
    var savePath = file.path + '/' + fileName;
    var filePath = File(savePath);
    var checkIsExists = await filePath.exists();
    if (checkIsExists) {
      await filePath.delete();
    }
  }

  @override
  Future<String?> getDownloadedFile(String name) async {
    if (kIsWeb) return null;
    var file = await getApplicationDocumentsDirectory();
    var savePath = file.path + '/' + name;
    var filePath = File(savePath);

    return await filePath.exists() ? filePath.path : null;
  }
}

@riverpod
DownloaderRepositoryImpl downloaderRepository(DownloaderRepositoryRef ref) {
  return DownloaderRepositoryImpl(
    client: DioApiService(),
    ref: ref,
  );
}
