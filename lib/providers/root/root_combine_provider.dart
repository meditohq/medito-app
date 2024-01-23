import 'package:Medito/providers/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final rootCombineProvider = Provider.family<void, BuildContext>((ref, context) {
  ref.read(remoteStatsProvider);
  ref.read(authProvider.notifier).saveFcmTokenEvent();
  ref.read(postLocalStatsProvider);
  ref.read(deviceAppAndUserInfoProvider);
  ref.read(audioDownloaderProvider).deleteDownloadedFileFromPreviousVersion();
});
