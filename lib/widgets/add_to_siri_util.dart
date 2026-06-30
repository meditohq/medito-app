import 'dart:io';
import 'package:flutter/services.dart';

void addToSiri({
  required String title,
  required String id,
  required String url,
}) {
  if (!Platform.isIOS) return;

  const channel = MethodChannel('com.medito.app/siri');
  channel.invokeMethod('donateShortcut', {
    'title': title,
    'id': id,
    'url': url,
  });
}
