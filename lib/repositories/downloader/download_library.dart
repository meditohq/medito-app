import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medito/models/track/track.dart';
import 'package:medito/repositories/track/track_repository.dart';

final downloadLibraryProvider = Provider<DownloadLibrary>(
  (ref) => DownloadLibrary(ref.watch(trackRepositoryProvider)),
);

/// Share one read/modify/write queue across native, manual and batch downloads
/// so simultaneous completions cannot replace each other's saved entries.
class DownloadLibrary {
  DownloadLibrary(this.repository);
  final TrackRepository repository;
  Future<void> _writes = Future.value();

  Future<void> update(List<Track> Function(List<Track>) edit) {
    final write = _writes.then((_) async {
      final current = await repository.fetchTrackFromPreference();
      await repository.addTrackInPreference(edit(current));
    });
    _writes = write.catchError((Object _) {});
    return write;
  }
}
