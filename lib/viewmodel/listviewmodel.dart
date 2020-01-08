import 'dart:async';

import 'package:medito/viewmodel/filemodel.dart';

import 'ListItemModel.dart';

abstract class MainListViewModel {
  Sink get inputTextSink;

  Stream<List<FolderModel>> get sessionListStream;

  void dispose();
}

class SubscriptionViewModelImpl implements MainListViewModel {
  var _mailTextController = StreamController<String>.broadcast();
  List<String> list = ["Home"];
  int currentPage;

  List<FolderModel> folders = [
    FolderModel("", "0 Meditate", 0, -1, ""),
    FolderModel("", "1 Loving-Kindness", 1, 0,
        "Be kind to yourself, be kind to others. Great in any situation",
        filesId: 1),
    FolderModel("", "Subfolder 1.1", 2, 1, ""),
    FolderModel("", "Subfolder 1.1.1", 3, 2, ""),
    FolderModel("", "Subfolder 1.1.2", 4, 2, ""),
    FolderModel("", "Subfolder 1.1.3", 5, 2, ""),
    FolderModel("", "Mindfulness of breathing", 6, 1,
        "A simple way to relax and feel less stressed. The only thing to do is being aware of your breathing",
        filesId: 2),
    FolderModel("", "Subfolder 1.1.1", 7, 6, ""),
    FolderModel("", "Subfolder 1.1.2", 8, 6, ""),
    FolderModel("", "Subfolder 1.1.3", 9, 6, ""),
    FolderModel("", "Mantra", 10, 0,
        "Use sound as an effective way to improve focus, to find more calm and calm your mind"),
    FolderModel("", "Subfolder 2.1", 11, 10, ""),
    FolderModel("", "Subfolder 2.2", 12, 10, ""),
    FolderModel("", "Folder 3", 13, 10, ""),
  ];

  List<FileModel> fileList = [
    FileModel("File 1", 1, type: FileType.audio),
    FileModel("File 2", 1, type: FileType.text),
    FileModel("File 3", 1, type: FileType.audio),
    FileModel("File 4", 1),
    FileModel("File 4", 1),
    FileModel("File 5", 2, type: FileType.audio),
    FileModel("File 6", 2,  type: FileType.text),
  ];

  @override
  Sink get inputTextSink => _mailTextController;

  @override
  Stream<List<FolderModel>> get sessionListStream =>
      Stream<List<FolderModel>>.value(List<FolderModel>.generate(15, (i) {
        return null;
      }));

  @override
  void dispose() => _mailTextController.close();

  List<FolderModel> getFolderContents(int currentPage) {
    this.currentPage = currentPage;
    return folders.where((f) => f.parentId == currentPage).toList();
  }

  List<FolderModel> backUp() {
    var parentItem = folders.where((f) => f.id == currentPage).toList();
    this.currentPage = parentItem.first.id;
    var result = getFolderContents(parentItem.first.parentId);
    list.removeLast();
    return result;
  }

  List<FolderModel> getFirstFolderContents() {
    return folders.where((f) => f.id == 0).toList();
  }

  List<FileModel> getFilesForId(int id) {
    print("!");
    return fileList.where((f) => f.folderId == id).toList();
  }

  void addToNavList(String title) {
    list.add(title);
  }
}
