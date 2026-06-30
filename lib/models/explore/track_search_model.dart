class TrackSearchModel {
  final String id;
  final String title;
  final String subtitle;
  final String description;
  final String coverUrl;
  final String path;

  const TrackSearchModel({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.description,
    required this.coverUrl,
    required this.path,
  });

  factory TrackSearchModel.fromJson(Map<String, dynamic> json) {
    return TrackSearchModel(
      id: json['id'] as String,
      title: json['title'] as String,
      subtitle: json['subtitle'] as String,
      description: json['description'] as String,
      coverUrl: json['coverUrl'] as String,
      path: json['path'] as String,
    );
  }
}
