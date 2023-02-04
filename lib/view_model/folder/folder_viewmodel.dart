import 'package:Medito/models/folder/folder_model.dart';
import 'package:Medito/repositories/folder/folder_repository.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'folder_viewmodel.g.dart';

@riverpod
Future<FolderModel> fetchFolders(
  FetchFoldersRef ref, {
  required int folderId,
}) {
  return ref.watch(folderRepositoryProvider).fetchFolders(folderId);
}
