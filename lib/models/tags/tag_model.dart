/// One content tag, e.g. `sleep` in group `goal`.
///
/// The server sends the tag's English classifier text as `description`; the
/// user-facing label comes from the app's own translations, see
/// `tagLabel` in `lib/utils/tag_labels.dart`.
class TagModel {
  const TagModel({
    required this.id,
    required this.group,
    required this.description,
  });

  final String id;
  final String group;
  final String description;

  static TagModel? tryFromJson(Object? json) {
    if (json is! Map) return null;
    final id = json['id'];
    if (id is! String || id.isEmpty) return null;
    final group = json['group'];
    final description = json['description'];
    return TagModel(
      id: id,
      group: group is String ? group : '',
      description: description is String ? description : '',
    );
  }
}

/// Everything `GET /tags` returns: the tag list plus a track → tag ids map
/// (tag ids ordered strongest first).
class TagCatalog {
  TagCatalog({required List<TagModel> tags, required this.trackTags})
    : tags = List.unmodifiable(tags),
      _byId = {for (final t in tags) t.id: t};

  final List<TagModel> tags;
  final Map<String, List<String>> trackTags;
  final Map<String, TagModel> _byId;

  static final empty = TagCatalog(tags: const [], trackTags: const {});

  bool get isEmpty => tags.isEmpty || trackTags.isEmpty;

  TagModel? tag(String id) => _byId[id];

  /// Tags for one track, strongest first. Empty when unknown.
  List<TagModel> tagsForTrack(String trackId) =>
      (trackTags[trackId] ?? const []).map(tag).whereType<TagModel>().toList();

  /// Tags shared by at least half of [trackIds], most common first. Used to
  /// describe a pack from its tracks without tagging packs server-side.
  List<TagModel> tagsForTracks(Iterable<String> trackIds) {
    // Every supplied track counts toward the denominator; a track missing from
    // the catalog simply contributes no tags, so it cannot lower the threshold.
    final ids = trackIds.toList();
    if (ids.isEmpty) return const [];
    final counts = <String, int>{};
    for (final id in ids) {
      for (final tagId in (trackTags[id] ?? const <String>[])) {
        counts[tagId] = (counts[tagId] ?? 0) + 1;
      }
    }
    final threshold = (ids.length / 2).ceil();
    final shared = counts.entries.where((e) => e.value >= threshold).toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return shared.map((e) => tag(e.key)).whereType<TagModel>().toList();
  }

  /// How many tracks carry each tag.
  Map<String, int> get trackCounts {
    final counts = <String, int>{};
    for (final tagIds in trackTags.values) {
      for (final id in tagIds) {
        counts[id] = (counts[id] ?? 0) + 1;
      }
    }
    return counts;
  }

  /// Lenient parser: anything malformed yields [empty] rather than throwing,
  /// so a bad or missing response simply hides every tag surface.
  factory TagCatalog.fromJson(Map<String, dynamic> json) {
    final rawTags = json['tags'];
    final rawMap = json['trackTags'];
    if (rawTags is! List || rawMap is! Map) return empty;

    final tags = rawTags
        .map(TagModel.tryFromJson)
        .whereType<TagModel>()
        .toList();
    final trackTags = <String, List<String>>{};
    for (final entry in rawMap.entries) {
      final key = entry.key;
      final value = entry.value;
      if (key is String && value is List) {
        trackTags[key] = value.whereType<String>().toList();
      }
    }
    return TagCatalog(tags: tags, trackTags: trackTags);
  }
}
