import 'package:Medito/models/models.dart';
import 'package:Medito/repositories/repositories.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
part 'folder_viewmodel.g.dart';

@riverpod
Future<FolderModel> folders(
  FoldersRef ref, {
  required int folderId,
}) {
  final folderRepository = ref.watch(folderRepositoryProvider);
  return folderRepository.fetchFolders(folderId);
}
