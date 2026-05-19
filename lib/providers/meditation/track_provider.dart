import 'package:medito/exceptions/app_error.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../models/track/track.dart';
import '../../repositories/track/track_repository.dart';

part 'track_provider.g.dart';

@riverpod
class Tracks extends _$Tracks {
  @override
  Future<Track> build({required String trackId}) async {
    final trackRepository = ref.watch(trackRepositoryProvider);
    try {
      final track = await trackRepository.fetchTrack(trackId);
      return track;
    } catch (error) {
      if (error is AppError) {
        rethrow;
      }
      throw const UnknownError();
    }
  }
}
