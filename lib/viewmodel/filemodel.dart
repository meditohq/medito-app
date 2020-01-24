class FileModel {
  String fileName;
  String fileUrl;
  int folderId;
  String transcription;
  FileType type;

  FileModel(this.fileName, this.folderId, {this.fileUrl ,this.type, this. transcription});
}

enum FileType { text, audio }
