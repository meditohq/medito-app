import 'package:Medito/network/home/home_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('test greeting text', () async {
    var bloc = HomeBloc();
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
}
