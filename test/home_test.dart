import 'package:Medito/network/api_response.dart';
import 'package:Medito/network/home/home_bloc.dart';
import 'package:Medito/network/home/home_repo.dart';
import 'package:Medito/network/home/menu_response.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockHomeRepo extends Mock implements HomeRepo {}

void main() {
  late HomeRepo _mockHomeRepo;
  late HomeBloc _bloc;

  setUp(() {
    _mockHomeRepo = MockHomeRepo();
    _bloc = HomeBloc(repo: _mockHomeRepo);
  });

  test('test greeting text', () async {
    var bloc = HomeBloc(repo: _mockHomeRepo);
    var now = DateTime(2021, 3, 1, 12, 30);
    var b = await bloc.getTitleText(now);
    expect(b, 'Good afternoon');

    //morning starts at 2
    now = DateTime(2021, 3, 1, 2, 01);
    b = await bloc.getTitleText(now);
    expect(b, 'Good morning');

    now = DateTime(2021, 3, 1, 1, 30);
    b = await bloc.getTitleText(now);
    expect(b, 'Good evening');

    now = DateTime(2021, 3, 1, 19, 30);
    b = await bloc.getTitleText(now);
    expect(b, 'Good evening');
  });

  test('menuList should broadcast ApiResponse data when repo responses data',
      () async {
    var expectedMenuResponse = _createMockMenuResponse();
    when(() => _mockHomeRepo.fetchMenu(false))
        .thenAnswer((realInvocation) async => expectedMenuResponse);
    var bloc = HomeBloc(repo: _mockHomeRepo);
    var firstResponse = bloc.menuList.stream.first;

    await bloc.fetchMenu();
    expect(await firstResponse, ApiResponse.completed(expectedMenuResponse));
  });

  test('menuList should broadcast ApiResponse error when repo throws',
      () async {
    when(() => _mockHomeRepo.fetchMenu(false)).thenThrow(Error());
    var firstResponse = _bloc.menuList.stream.first;

    await _bloc.fetchMenu();
    var apiResponse = (await firstResponse);
    expect(apiResponse.status, Status.ERROR);
    expect(apiResponse.body, null);
  });

  tearDown(() {
    _bloc.dispose();
  });
}

MenuResponse _createMockMenuResponse() {
  var item = {
    'item_label': 'mock_item_label',
    'item_type': 'mock_item_type',
    'item_path': 'mock_item_path'
  };
  var mockData = {
    'data': [item]
  };
  return MenuResponse.fromJson(mockData);
}
