# Watch downloads

Downloads always shows **On phone** and **On watch** tabs. The watch view shows a checking state during discovery, then “No watch connected” if no compatible Medito watch app is detected; cached entries remain visible. Phone rows offer Send to watch; Select sends several sessions. Each request uses the downloaded voice, duration and audio file, rather than resolving current playback preferences again.

The watch view includes queued, sending, ready, failed and removal-pending sessions. Ready requires a watch acknowledgement after the complete file is saved. Failed transfers can be retried while their phone download exists. Cancellation and removal refer to the request ID, so late transfers and acknowledgements cannot restore a removed copy or delete a newer replacement. Removing a phone download preserves the watch copy. Queued transfers use a staged phone file, so phone deletion also cannot interrupt them.

Both watch apps have a Downloads screen with offline playback and removal. Their normal players also prefer a downloaded copy matching the audio file ID. Sign-out clears watch downloads and pending phone transfers.

## Platform transport

- Apple Watch: WatchConnectivity background file transfers, user-info removal commands and watch acknowledgements. Live inventory requests preflight storage; communication waits at most three seconds before queueing. The receiver validates byte count and free space before saving.
- Wear OS: a persisted Data Layer item containing the audio Asset, received by a background listener service. A request/reply storage check runs before sending when connected. Previously discovered watches can receive queued requests when they reconnect. Saved copies live in the watch app's private storage; the phone releases the replicated asset after acknowledgement. Transfer progress is shown only where the platform exposes a meaningful value.

Storage preflight allows room for receiving and saving the file, plus queued requests. It is advisory: the watch checks again when saving, since other apps may use space in the meantime.

## Verification

Run the Flutter tests in `test/services/watch_download_service_test.dart` and `test/views/downloads_view_test.dart`. Compile both Android modules and build the MeditoWatch scheme for watchsimulator. The iPhone bridge can also be type-checked independently against Flutter.framework.

Apple documents WatchConnectivity file-transfer testing on paired physical devices. Simulator sends return an explicit unsupported-transfer error instead of queueing indefinitely; old simulator requests display the same explanation. The simulator can verify build and screen behavior, but cannot establish that background audio transfers, reconnects, storage failures, and offline playback work on physical hardware. Before release, verify those cases on both Apple Watch and Wear OS, including restarting either app during a transfer, cancelling before receipt, deleting a phone copy while queued, deleting from the watch while disconnected, retrying the same variant and signing out during a transfer.
