import 'dart:async';

import 'package:Medito/data/audio_complete_copy_response.dart';
import 'package:Medito/viewmodel/http_get.dart';
import 'package:flutter/foundation.dart';

class AudioCompleteCopyProvider extends ChangeNotifier {
  var baseUrl = 'https://medito.app/api/pages';

  Future<Versions> fetchCopy() async {
    try {
      final response = await httpGet(baseUrl + "/service+audiocompletecopy");

      if (response != null) {
        var copy = AudioCompleteCopyResponse.fromJson(response);

        var versions = copy.data.content.versions;

        var sticky = versions.firstWhere((element) => element?.sticky,
            orElse: () => null);
        if (sticky != null) {
          return sticky;
        } else {
          versions.shuffle();
          return versions.first;
        }
      }
      return null;
    } on Exception {
      return null;
    }
  }
}
