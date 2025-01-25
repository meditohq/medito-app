import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:internet_connection_checker/internet_connection_checker.dart';

final internetConnectionProvider =
    StreamProvider<InternetConnectionStatus>((ref) {
  final stream = InternetConnectionChecker.instance.onStatusChange;

  return stream;
});
