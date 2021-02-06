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

import 'package:shared_preferences/shared_preferences.dart';

const DEFAULT_VOLUME = 60.0;

Future<dynamic> retrieveSavedBgVolume() async {
  var prefs = await SharedPreferences.getInstance();
    return prefs.getInt('bgVolume')?.toDouble() ?? DEFAULT_VOLUME;
}

Future<void> saveBgVolume(double volume) async {
  var prefs = await SharedPreferences.getInstance();
  await prefs.setInt('bgVolume', volume.toInt());
}
