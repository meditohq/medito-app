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

import 'package:Medito/components/components.dart';
import 'package:Medito/constants/constants.dart';
import 'package:Medito/models/models.dart';
import 'package:Medito/routes/routes.dart';
import 'package:Medito/view_model/session/session_viewmodel.dart';
import 'package:Medito/views/session/components/session_buttons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SessionViewScreen extends ConsumerWidget {
  final String? id;
  final Screen? screenKey;

  SessionViewScreen({Key? key, this.id, this.screenKey}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var sessions = ref.watch(sessionsProvider(sessionId: 9));
    return Scaffold(
      body: sessions.when(
        skipLoadingOnRefresh: false,
        data: (data) => _buildScaffoldWithData(context, data, ref),
        error: (err, stack) => ErrorComponent(
          message: err.toString(),
          onTap: () async => await ref.refresh(sessionsProvider(sessionId: int.parse(id!))),
        ),
        loading: () => _buildLoadingWidget(),
      ),
    );
  }

  Padding _buildLoadingWidget() => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 15),
        child: const SessionShimmerComponent(),
      );

  RefreshIndicator _buildScaffoldWithData(
      BuildContext context, SessionModel sessionModel, WidgetRef ref) {
    return RefreshIndicator(
      onRefresh: () async => await ref.refresh(sessionsProvider(sessionId: int.parse(id!))),
      child: Scaffold(
        body: CollapsibleHeaderComponent(
          bgImage: sessionModel.coverUrl,
          title: sessionModel.title,
          description: sessionModel.description,
          children: [
            _mainContent(context, sessionModel),
          ],
        ),
      ),
    );
  }

  Widget _mainContent(BuildContext context, SessionModel sessionModel) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(height: 24),
          Text(
            'Select a guide / duration',
            style: Theme.of(context)
                .primaryTextTheme
                .bodyLarge
                ?.copyWith(color: ColorConstants.newGrey, fontFamily: DmSans),
          ),
          height16,
          SessionButtons(
            sessionModel: sessionModel,
          )
        ],
      ),
    );
  }
}
