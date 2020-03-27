class TileItem {
  String thumbnail;
  String title;
  String id;
  String description = '';
  String url;
  String parentId;
  String pathType;
  TileType tileType;
  String contentPath;
  String colorBackground;
  String colorButton;
  String colorButtonText;
  String colorText;
  String buttonLabel;

  TileItem(this.title, this.id,
      {this.description,
      this.url,
      this.parentId,
      this.thumbnail,
      this.tileType,
      this.contentPath,
      this.colorBackground,
      this.colorButton,
      this.pathType,
      this.colorButtonText,
      this.colorText,
      this.buttonLabel});
}

enum TileType { large, small, announcement }
