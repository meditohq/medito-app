import 'package:flutter/widgets.dart';

/// Reveal the existing main route after selecting Home. A warm notification
/// tap can arrive while a detail screen or dialog covers the bottom navigation.
void revealSupporterCampaignHome(BuildContext mainContext) {
  final mainRoute = ModalRoute.of(mainContext);
  if (mainRoute == null) return;
  Navigator.of(mainContext).popUntil((route) => route == mainRoute);
}
