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

import 'package:Medito/widgets/folders/loading_item_widget.dart';
import 'package:flutter/material.dart';

class LoadingListWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Stack(
      children: <Widget>[
        getListView(),
        GestureDetector(
          onTap: () => _pop(context),
          child: Container(
            height: 200,
            color: Colors.transparent,
          ),
        ),
      ],
    );
  }

  ListView getListView() {
    return ListView.builder(
      shrinkWrap: true,
        itemCount: 6,
        itemBuilder: (context, i) {
          return LoadingItemWidget(index: i + 1);
        });
  }

  void _pop(BuildContext context) {
    Navigator.pop(context);
  }
}
