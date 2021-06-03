import 'package:Medito/network/downloads/downloads_bloc.dart';
import 'package:Medito/utils/colors.dart';
import 'package:Medito/utils/duration_ext.dart';
import 'package:Medito/utils/navigation.dart';
import 'package:Medito/utils/strings.dart';
import 'package:Medito/utils/utils.dart';
import 'package:Medito/widgets/empty_widget.dart';
import 'package:Medito/widgets/main/app_bar_widget.dart';
import 'package:Medito/widgets/packs/pack_list_item.dart';
import 'package:Medito/widgets/player/player_widget.dart';
import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';

class FavouriteListWidget extends StatefulWidget {
  @override
  _FavListWidgetState createState() => _FavListWidgetState();
}

class _FavListWidgetState extends State<FavouriteListWidget>
    with SingleTickerProviderStateMixin {
  final key = GlobalKey<AnimatedListState>();
  var scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const MeditoAppBarWidget(
        title: FAVOURITES,
        transparent: true,
        hasCloseButton: true,
      ),
      key: scaffoldKey,
      body: _getLibraryList(),
    );
  }

  Widget _getLibraryList() {
    return EmptyStateWidget(
        message: EMPTY_FAVORITES_MESSAGE,
        image: SvgPicture.asset(
          'assets/images/favorites.svg',
          height: 154,
          width: 184,
        ));
  }

}
