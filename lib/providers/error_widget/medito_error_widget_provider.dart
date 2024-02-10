import 'package:flutter_riverpod/flutter_riverpod.dart';

final meditoErrorWidgetProvider =
    Provider.family<MeditoErrorWidgetUIState, MeditoErrorWidgetUIState>(
  (ref, data) {
    try {
      if (data.shouldShowCheckDownloadButton) {
        return MeditoErrorWidgetUIState(true, data.message);
      }
      var splitMessage = data.message.split(': ');
      if (splitMessage.length > 1) {
        var statusCode = int.parse(splitMessage[1]);
        if (statusCode >= 500 && statusCode < 600) {
          return MeditoErrorWidgetUIState(true, splitMessage[0]);
        }
      }

      return MeditoErrorWidgetUIState(false, splitMessage[0]);
    } catch (e) {
      return MeditoErrorWidgetUIState(false, data.message);
    }
  },
);

//ignore: prefer-match-file-name
class MeditoErrorWidgetUIState {
  final bool shouldShowCheckDownloadButton;
  final String message;

  MeditoErrorWidgetUIState(this.shouldShowCheckDownloadButton, this.message);
}
