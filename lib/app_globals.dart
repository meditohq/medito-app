import 'dart:async';

// Completes when the app has finished auth/init and landed on the main screen.
// Deep link navigation waits for this before pushing any route.
// This is non-final so it can be reset after a force logout.
var appReadyCompleter = Completer<void>();
