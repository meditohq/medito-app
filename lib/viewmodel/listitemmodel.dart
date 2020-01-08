class FolderModel {
  String thumbnail;
  String title;
  int id;
  int parentId;
  String description;
  int filesId;

  FolderModel(
      this.thumbnail, this.title, this.id, this.parentId, this.description,
      {this.filesId = -1});
}
