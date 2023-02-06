import 'package:Medito/models/models.dart';
import 'package:Medito/repositories/repositories.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
part 'folder_viewmodel.g.dart';

@riverpod
Future<FolderModel> fetchFolders(
  FetchFoldersRef ref, {
  required int folderId,
}) {
  return ref.watch(folderRepositoryProvider).fetchFolders(folderId);
}
