import 'package:Medito/constants/constants.dart';
import 'package:Medito/models/models.dart';
import 'package:Medito/providers/providers.dart';
import 'package:Medito/routes/routes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

final rootCombineProvider = Provider.family<void, BuildContext>((ref, context) {
  ref.read(remoteStatsProvider);
  ref.read(authProvider.notifier).saveFcmTokenEvent();
  ref.read(postLocalStatsProvider);
  ref.read(deviceAppAndUserInfoProvider);
  ref.read(audioDownloaderProvider).deleteDownloadedFileFromPreviousVersion();
});
