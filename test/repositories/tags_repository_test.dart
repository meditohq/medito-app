import 'package:flutter_test/flutter_test.dart';
import 'package:medito/repositories/tags/tags_repository.dart';
import 'package:medito/services/network/http_api_service.dart';
import 'package:mocktail/mocktail.dart';

class MockHttpApiService extends Mock implements HttpApiService {}

void main() {
  late MockHttpApiService client;
  late TagsRepositoryImpl repo;

  setUp(() {
    client = MockHttpApiService();
    repo = TagsRepositoryImpl(client: client);
  });

  test('fetchCatalog hits GET tags and parses the catalog', () async {
    when(() => client.getRequest('tags')).thenAnswer(
      (_) async => {
        'tags': [
          {'id': 'sleep', 'group': 'goal', 'description': 'd'},
        ],
        'trackTags': {'t1': ['sleep']},
      },
    );
    final catalog = await repo.fetchCatalog();
    expect(catalog.tags.single.id, 'sleep');
    expect(catalog.tagsForTrack('t1').single.id, 'sleep');
  });

  test('fetchCatalog propagates network failures', () async {
    when(() => client.getRequest('tags')).thenThrow(Exception('offline'));
    expect(repo.fetchCatalog(), throwsException);
  });

  test('fetchTracksForTag parses track cards and drops malformed rows', () async {
    when(() => client.getRequest('tags/sleep')).thenAnswer(
      (_) async => {
        'tag': {'id': 'sleep', 'group': 'goal', 'description': 'd'},
        'tracks': [
          {
            'id': 'a',
            'title': 'Drift off',
            'subtitle': '10 min',
            'coverUrl': 'https://x/a.png',
            'path': '/tracks/a',
            'probability': 0.9,
          },
          {'id': 'b', 'title': 'Minimal'},
          {'title': 'no id'},
          'garbage',
        ],
      },
    );
    final tracks = await repo.fetchTracksForTag('sleep');
    expect(tracks.map((t) => t.id), ['a', 'b']);
    expect(tracks.first.subtitle, '10 min');
    expect(tracks.last.path, '/tracks/b');
    expect(tracks.last.coverUrl, '');
  });

  test('fetchTracksForTag returns empty for an unexpected body', () async {
    when(() => client.getRequest('tags/sleep')).thenAnswer((_) async => {});
    expect(await repo.fetchTracksForTag('sleep'), isEmpty);
  });
}
