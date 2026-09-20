import 'package:medito/constants/constants.dart';
import 'package:medito/models/explore/explore_list_item.dart';
import 'package:medito/models/tags/tag_model.dart';
import 'package:medito/services/network/http_api_service.dart';

abstract class TagsRepository {
  /// All tags and the track → tags map. Throws on network failure.
  Future<TagCatalog> fetchCatalog();

  /// Tracks carrying [tagId], strongest match first. Throws on network failure.
  Future<List<TrackItem>> fetchTracksForTag(String tagId);
}

class TagsRepositoryImpl implements TagsRepository {
  TagsRepositoryImpl({required this.client});

  final HttpApiService client;

  @override
  Future<TagCatalog> fetchCatalog() async {
    final response = await client.getRequest(HTTPConstants.tags);
    return TagCatalog.fromJson(response);
  }

  @override
  Future<List<TrackItem>> fetchTracksForTag(String tagId) async {
    final response = await client.getRequest('${HTTPConstants.tags}/$tagId');
    final tracks = response['tracks'];
    if (tracks is! List) return const [];
    return tracks
        .whereType<Map>()
        .where((t) => t['id'] is String && t['title'] is String)
        .map(
          (t) => TrackItem(
            id: t['id'] as String,
            title: t['title'] as String,
            subtitle: t['subtitle'] as String? ?? '',
            coverUrl: t['coverUrl'] as String? ?? '',
            path: t['path'] as String? ?? '/tracks/${t['id']}',
          ),
        )
        .toList();
  }
}
