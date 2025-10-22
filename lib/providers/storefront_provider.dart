import 'dart:ui';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'storefront_provider.g.dart';

@riverpod
bool isUSStorefront(Ref ref) {
  final locale = PlatformDispatcher.instance.locale;
  final countryCode = locale.countryCode?.toUpperCase();

  return countryCode == 'US';
}
