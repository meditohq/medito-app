/*This file is part of Medito App.

Medito App is free software: you can redistribute it and/or modify
it under the terms of the Affero GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

Medito App is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
Affero GNU General Public License for more details.

You should have received a copy of the Affero GNU General Public License
along with Medito App. If not, see <https://www.gnu.org/licenses/>.*/

import 'dart:async';

import 'package:Medito/network/text/text_repo.dart';

class TextBloc {
  StreamController<String> titleController = StreamController.broadcast()..sink.add('...');
  StreamController<String> bodyController = StreamController.broadcast()..sink.add('...');
  final _repo = TextRepository();

  Future<void> fetchText(String? id, bool skipCache) async {
    if (id != null) {
      var data = await _repo.fetchData(id, skipCache);

      if (!titleController.isClosed) {
        titleController.sink.add(data?.title ?? '');
      }
      if (!bodyController.isClosed) {
        bodyController.sink.add(data?.body ?? '');
      }
    }
  }

  void dispose() {
    titleController.close();
    bodyController.close();
  }
}
