import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AddToSiriButton extends StatelessWidget {
  final String title;
  final String url;
  final String id;
  final Widget child;

  const AddToSiriButton({
    super.key,
    required this.title,
    required this.id,
    required this.url,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    if (!Platform.isIOS) {
      return const SizedBox();
    }

    return Padding(
      padding: const EdgeInsets.only(left: 10.0),
      child: InkWell(
        onTap: () {
          const channel = MethodChannel('com.medito.app/siri');
          channel.invokeMethod('donateShortcut', {
            'title': title,
            'id': id,
            'url': url,
          });
        },
        child: child,
      ),
    );
  }
} 