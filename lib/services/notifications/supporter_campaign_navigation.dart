import 'package:flutter/widgets.dart';
import 'package:medito/utils/pending_end_screen.dart';

/// Reveal the existing main route after selecting Home. A warm notification
/// tap can arrive while a detail screen or dialog covers the bottom navigation.
/// Never during a session: popping the player stops the meditation, and
/// popping its end screen loses the summary. Home is selected underneath.
void revealSupporterCampaignHome(BuildContext mainContext) {
  if (PendingEndScreen.hasLiveSessionScreen) return;
  final mainRoute = ModalRoute.of(mainContext);
  if (mainRoute == null) return;
  Navigator.of(mainContext).popUntil((route) => route == mainRoute);
}
