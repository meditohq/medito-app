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
        var copy = AudioCompleteCopyResponse.fromJson(response).data.content.versions;

        copy.retainWhere((value) => value.active);

        copy.shuffle();
        var version = copy.first;

        var numberOfSession = await getNumSessionsInt() + 1;

        version.title =
            version.title.replaceAll('%n', numberOfSession.toString());

        setVersionCopySeen(version.version);

        return version;
      }
      return null;
    } catch(e){
      print(e.toString());
    }
  }
}
