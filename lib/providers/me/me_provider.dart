import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../models/me/me_model.dart';
import '../../repositories/me/me_repository.dart';

part 'me_provider.g.dart';

@riverpod
Future<MeModel> me(Ref ref) {
  ref.keepAlive();

  return ref.watch(meRepositoryProvider).fetchMe();
}
