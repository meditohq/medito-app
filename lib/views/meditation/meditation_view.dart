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
import 'package:Medito/providers/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'components/meditation_buttons.dart';

class MeditationView extends ConsumerWidget {
  final String? id;
  final Screen? screenKey;

  MeditationView({Key? key, this.id, this.screenKey}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var meditations =
        ref.watch(meditationsProvider(meditationId: int.parse(id!)));

    return Scaffold(
      body: meditations.when(
        skipLoadingOnRefresh: false,
        data: (data) => _buildScaffoldWithData(context, data, ref),
        error: (err, stack) => ErrorComponent(
          message: err.toString(),
          onTap: () =>
              ref.refresh(meditationsProvider(meditationId: int.parse(id!))),
        ),
        loading: () => _buildLoadingWidget(),
      ),
    );
  }

  Padding _buildLoadingWidget() => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 15),
        child: const MeditationShimmerComponent(),
      );

  RefreshIndicator _buildScaffoldWithData(
    BuildContext context,
    MeditationModel meditationModel,
    WidgetRef ref,
  ) {
    return RefreshIndicator(
      onRefresh: () async =>
          await ref.refresh(meditationsProvider(meditationId: int.parse(id!))),
      child: Scaffold(
        body: CollapsibleHeaderComponent(
          bgImage: meditationModel.coverUrl,
          title: meditationModel.title,
          description: meditationModel.description,
          children: [
            _mainContent(context, meditationModel),
          ],
        ),
      ),
    );
  }

  Widget _mainContent(BuildContext context, MeditationModel meditationModel) {
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
          MeditationButtons(
            meditationModel: meditationModel,
          ),
        ],
      ),
    );
  }
}
