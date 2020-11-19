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

import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> savePurchases(List<PurchaseDetails> purchases) async {
  var prefs = await SharedPreferences.getInstance();

  var keys = prefs.getStringList('purchaseKeys') ?? [];
  purchases.forEach((element) {
    keys.add(element.productID + ' ' + element.purchaseID);
  });
}

Future<void> saveEmailAddress(String email) async {
  var prefs = await SharedPreferences.getInstance();
  prefs.setString('emailAddress', email);
}

Future<String> getEmailAddress() async {
  var prefs = await SharedPreferences.getInstance();
  return prefs.getString('emailAddress') ?? "";
}
