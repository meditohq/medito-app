import 'package:flutter_riverpod/flutter_riverpod.dart';

final meditoErrorWidgetProvider =
    Provider.family<MeditoErrorWidgetUIState, MeditoErrorWidgetUIState>((
      ref,
      data,
    ) {
      try {
        // Show downloads button for connectivity issues
        var shouldShowDownloads =
            data.shouldShowCheckDownloadButton ||
            data.message ==
                'Make sure you are connected to the internet to use Medito' ||
            data.message ==
                'Oops! It seems like there was an error. If the problem persists, Close the app and try again.';

        return MeditoErrorWidgetUIState(shouldShowDownloads, data.message);
      } catch (e) {
        return MeditoErrorWidgetUIState(
          false,
          "An unknown error occurred. Either we're having issues or you're offline.",
        );
      }
    });

//ignore: prefer-match-file-name
class MeditoErrorWidgetUIState {
  final bool shouldShowCheckDownloadButton;
  final String message;

  MeditoErrorWidgetUIState(this.shouldShowCheckDownloadButton, this.message);
}
