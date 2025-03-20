import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'dart:developer' as dev;

import '../../models/me/me_model.dart';
import '../../repositories/me/me_repository.dart';

part 'me_provider.g.dart';

@Riverpod(keepAlive: true)
Future<MeModel> me(Ref ref) {
  dev.log('[ME_PROVIDER] me provider called');
  var repo = ref.read(meRepositoryProvider);
  dev.log('[ME_PROVIDER] got repository instance');
  return repo.fetchMe();
}

/// Provider to refresh the me provider
final meRefreshProvider = Provider<void Function()>((ref) {
  return () {
    dev.log('[ME_PROVIDER] invalidating me provider');
    ref.invalidate(meProvider);
    dev.log('[ME_PROVIDER] me provider invalidated');
  };
});
