import 'dart:async';

import 'package:Medito/data/audio_complete_copy_response.dart';
import 'package:Medito/utils/stats_utils.dart';
import 'package:Medito/viewmodel/http_get.dart';
import 'package:flutter/foundation.dart';

class AudioCompleteCopyProvider extends ChangeNotifier {
  var baseUrl = 'https://medito.app/api/pages';

  Future<Versions> fetchCopy() async {
    try {
      final response = await httpGet(baseUrl + "/service+audiocompletecopy",
          skipCache: true);

      if (response != null) {
        var copy = AudioCompleteCopyResponse.fromJson(response);

        var versions = copy.data.content.versions;

        var sticky = versions.firstWhere((element) => element?.sticky,
            orElse: () => null);
        if (sticky != null) {
          return sticky;
        } else {
          versions.shuffle();
          var version = versions.first;

          var numberOfSession = await getNumSessionsInt() + 1;

          version.title =
              version.title.replaceAll('%n', numberOfSession.toString());

          return version;
        }
      }
      return null;
    } on Exception {
      return null;
    }
  }
}
