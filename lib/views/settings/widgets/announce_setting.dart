import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

/// Confirms a choice made in a settings bottom sheet ("Theme: Dark"). The
/// sheet closes on tap and a screen reader otherwise says nothing about
/// whether the choice took. Call while [context] is still mounted.
void announceSettingChoice(BuildContext context, String title, String value) {
  SemanticsService.sendAnnouncement(
    View.of(context),
    '$title: $value',
    Directionality.of(context),
  );
}
