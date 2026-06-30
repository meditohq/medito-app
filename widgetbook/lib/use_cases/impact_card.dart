import 'package:flutter/material.dart';
import 'package:medito/widgets/impact_card.dart';
import 'package:widgetbook_annotation/widgetbook_annotation.dart';

@UseCase(name: 'Default', type: ImpactCard)
Widget defaultImpactCard(BuildContext context) {
  return const Padding(padding: EdgeInsets.all(16), child: ImpactCard());
}
