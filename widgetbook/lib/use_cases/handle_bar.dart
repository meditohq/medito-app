import 'package:flutter/material.dart';
import 'package:medito/widgets/handle_bar_widget.dart';
import 'package:widgetbook_annotation/widgetbook_annotation.dart';

@UseCase(name: 'Default', type: HandleBarWidget)
Widget defaultHandleBar(BuildContext context) {
  return const Center(child: HandleBarWidget());
}
