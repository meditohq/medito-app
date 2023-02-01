import 'package:Medito/constants/http/http_constants.dart';
import 'package:Medito/services/network/dio_api_services.dart';
import 'package:Medito/services/network/dio_client_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
part 'folder_repository.g.dart';

class FolderRepository {
  final DioApiService client;

  FolderRepository({required this.client});

  Future<void> fetchFolders(int folderId) async {
    await client.getRequest('${HTTPConstants.FOLDERS}/$folderId');
  }
}

@riverpod
FolderRepository folderRepository(FolderRepositoryRef ref) {
  return FolderRepository(client: ref.watch(dioClientProvider));
}
