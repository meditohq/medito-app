import 'package:Medito/models/models.dart';
import 'package:Medito/repositories/repositories.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
part 'session_viewmodel.g.dart';

@riverpod
Future<SessionModel> fetchSessions(
  FetchSessionsRef ref, {
  required int sessionId,
}) {
  return ref.watch(sessionRepositoryProvider).fetchSession(sessionId);
}
