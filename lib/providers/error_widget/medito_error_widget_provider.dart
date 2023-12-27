import 'package:flutter_riverpod/flutter_riverpod.dart';

final meditoErrorWidgetProvider =
    Provider.family<MeditoErrorWidgetUIState, MeditoErrorWidgetUIState>(
  (ref, data) {
    try {
      if (data.shouldShowCheckDownload) {
        return MeditoErrorWidgetUIState(true, data.message);
      }
      var splittedMessage = data.message.split(': ');
      if (splittedMessage.length > 1) {
        var statusCode = int.parse(splittedMessage[1]);
        if (statusCode >= 500 && statusCode < 600) {
          return MeditoErrorWidgetUIState(true, splittedMessage[0]);
        }
      }

      return MeditoErrorWidgetUIState(false, splittedMessage[0]);
    } catch (e) {
      return MeditoErrorWidgetUIState(false, data.message);
    }
  },
);

//ignore: prefer-match-file-name
class MeditoErrorWidgetUIState {
  final bool shouldShowCheckDownload;
  final String message;

  MeditoErrorWidgetUIState(this.shouldShowCheckDownload, this.message);
}
