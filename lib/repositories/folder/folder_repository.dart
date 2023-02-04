import 'package:Medito/constants/http/http_constants.dart';
import 'package:Medito/models/folder/folder_model.dart';
import 'package:Medito/services/network/dio_api_services.dart';
import 'package:Medito/services/network/dio_client_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
part 'folder_repository.g.dart';

abstract class FolderRepository {
  Future<FolderModel> fetchFolders(int folderId);
}

class FolderRepositoryImpl extends FolderRepository {
  final DioApiService client;

  FolderRepositoryImpl({required this.client});

  @override
  Future<FolderModel> fetchFolders(int folderId) async {
    try {
      var res = await client.getRequest('${HTTPConstants.FOLDERS}/$folderId');
      return FolderModel.fromJson(res);
    } catch (e) {
      rethrow;
    }
  }
}

@riverpod
FolderRepositoryImpl folderRepository(FolderRepositoryRef ref) {
  return FolderRepositoryImpl(client: ref.watch(dioClientProvider));
}
