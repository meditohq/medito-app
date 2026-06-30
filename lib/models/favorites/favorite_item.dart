enum FavoriteItemType { track, pack }

class FavoriteItemDto {
  final String id;
  final String title;
  final String? subtitle;
  final String? path;
  final String type;
  final int timestamp;

  const FavoriteItemDto({
    required this.id,
    required this.title,
    this.subtitle,
    this.path,
    required this.type,
    required this.timestamp,
  });

  factory FavoriteItemDto.fromJson(Map<String, dynamic> json) {
    return FavoriteItemDto(
      id: json['id'] as String,
      title: json['title'] as String,
      subtitle: json['subtitle'] as String?,
      path: json['path'] as String?,
      type: json['type'] as String,
      timestamp: json['timestamp'] as int,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'subtitle': subtitle,
      'path': path,
      'type': type,
      'timestamp': timestamp,
    };
  }
}

class FavoriteItem {
  final String id;
  final String title;
  final String? coverUrl;
  final String? subtitle;
  final FavoriteItemType type;
  final int timestamp;
  final String? path;

  const FavoriteItem({
    required this.id,
    required this.title,
    this.coverUrl,
    this.subtitle,
    required this.type,
    required this.timestamp,
    this.path,
  });

  factory FavoriteItem.fromDto(FavoriteItemDto dto) {
    return FavoriteItem(
      id: dto.id,
      title: dto.title,
      subtitle: dto.subtitle,
      path: dto.path,
      type: _getTypeFromString(dto.type),
      timestamp: dto.timestamp,
    );
  }

  factory FavoriteItem.fromJson(Map<String, dynamic> json) {
    return FavoriteItem(
      id: json['id'] as String,
      title: json['title'] as String,
      coverUrl: json['coverUrl'] as String?,
      subtitle: json['subtitle'] as String?,
      path: json['path'] as String?,
      type: FavoriteItemType.values.firstWhere(
        (e) => e.toString() == 'FavoriteItemType.${json['type']}',
        orElse: () => FavoriteItemType.track,
      ),
      timestamp:
          json['timestamp'] as int? ?? DateTime.now().millisecondsSinceEpoch,
    );
  }

  static FavoriteItemType _getTypeFromString(String type) {
    switch (type.toLowerCase()) {
      case 'track':
        return FavoriteItemType.track;
      case 'pack':
        return FavoriteItemType.pack;
      default:
        return FavoriteItemType.track;
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'coverUrl': coverUrl,
      'subtitle': subtitle,
      'path': path,
      'type': type.toString().split('.').last,
      'timestamp': timestamp,
    };
  }
}
