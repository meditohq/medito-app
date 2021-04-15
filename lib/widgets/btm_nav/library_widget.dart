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

import 'package:Medito/utils/colors.dart';
import 'package:Medito/utils/strings.dart';
import 'package:Medito/widgets/btm_nav/downloads_widget.dart';
import 'package:Medito/widgets/empty_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';

class LibraryWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: DefaultTabController(
        length: 2,
        child: Scaffold(
          appBar: PreferredSize(
            preferredSize: Size.fromHeight(kToolbarHeight),
            child: Container(
              height: 50.0,
              child: Container(
                decoration: BoxDecoration(
                    border: Border(
                        bottom: BorderSide(
                            color: MeditoColors.softGrey, width: 1.5))),
                child: TabBar(
                  unselectedLabelStyle: Theme.of(context)
                      .textTheme
                      .headline4
                      .copyWith(color: MeditoColors.meditoTextGrey),
                  labelStyle: Theme.of(context).textTheme.headline4,
                  isScrollable: false,
                  tabs: [
                    Tab(icon: Text('Downloads')),
                    Tab(icon: Text('Favourites')),
                  ],
                ),
              ),
            ),
          ),
          body: TabBarView(
            physics: NeverScrollableScrollPhysics(),
            children: [
              DownloadsListWidget(),
              EmptyStateWidget(
                  message: EMPTY_FAVORITES_MESSAGE,
                  image: SvgPicture.asset(
                    'assets/images/favorites.svg',
                    height: 154,
                    width: 184,
                  )),
            ],
          ),
        ),
      ),
    );
  }
}
