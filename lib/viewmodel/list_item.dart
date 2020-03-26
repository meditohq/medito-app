class ListItem {
  String thumbnail;
  String title;
  String id;
  String description = '';
  String contentText;
  ListItemType type;
  FileType fileType;
  String url;
  String parentId;

  ListItem(this.title, this.id, this.type,
      {this.description,
      this.fileType,
      this.url,
      this.parentId,
      this.thumbnail,
      this.contentText});
}

enum ListItemType { folder, file, illustration }
enum FileType { audio, text, both, audioset }
