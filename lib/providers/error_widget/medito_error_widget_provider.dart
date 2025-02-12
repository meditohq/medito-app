import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medito/constants/constants.dart';

final meditoErrorWidgetProvider =
    Provider.family<MeditoErrorWidgetUIState, MeditoErrorWidgetUIState>(
  (ref, data) {
    try {
      // Show downloads button for connectivity issues
      var shouldShowDownloads = data.shouldShowCheckDownloadButton ||
          data.message == StringConstants.connectivityError ||
          data.message == StringConstants.timeout;

      return MeditoErrorWidgetUIState(shouldShowDownloads, data.message);
    } catch (e) {
      return MeditoErrorWidgetUIState(false, StringConstants.anErrorOccurred);
    }
  },
);

//ignore: prefer-match-file-name
class MeditoErrorWidgetUIState {
  final bool shouldShowCheckDownloadButton;
  final String message;

  MeditoErrorWidgetUIState(this.shouldShowCheckDownloadButton, this.message);
}
