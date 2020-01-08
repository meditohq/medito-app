class FileModel {
  String fileName;
  String fileUrl;
  int folderId;
  FileType type;

  FileModel(this.fileName, this.folderId, {this.fileUrl ,this.type});
}

enum FileType { text, audio }
