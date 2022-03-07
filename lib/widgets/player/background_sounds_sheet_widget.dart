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

import 'package:Medito/audioplayer/medito_audio_handler.dart';
import 'package:Medito/audioplayer/player_utils.dart';
import 'package:Medito/network/api_response.dart';
import 'package:Medito/network/session_options/background_sounds.dart';
import 'package:Medito/utils/bgvolume_utils.dart';
import 'package:Medito/utils/colors.dart';
import 'package:Medito/utils/shared_preferences_utils.dart';
import 'package:Medito/utils/strings.dart';
import 'package:Medito/utils/utils.dart';
import 'package:Medito/widgets/player/position_indicator_widget.dart';
import 'package:back_button_interceptor/back_button_interceptor.dart';
import 'package:connectivity/connectivity.dart';
import 'package:flutter/material.dart';
import 'package:rxdart/rxdart.dart';

import '../../audioplayer/audio_inherited_widget.dart';
import '../../main.dart';

class ChooseBackgroundSoundDialog extends StatefulWidget {
  final stream;
  final MeditoAudioHandler handler;

  ChooseBackgroundSoundDialog({this.handler, this.stream});

  @override
  _ChooseBackgroundSoundDialogState createState() =>
      _ChooseBackgroundSoundDialogState();
}

class _ChooseBackgroundSoundDialogState
    extends State<ChooseBackgroundSoundDialog> {
  static const NONE = 'No Sound';
  bool isOffline = false;

  /// Tracks the bgVolume while the user drags the bgVolume bar.
  final BehaviorSubject<double> _dragBgVolumeSubject =
      BehaviorSubject.seeded(null);
  var volume;

  MeditoAudioHandler _handler;
  String _downloadingItem;

  @override
  void initState() {
    super.initState();
    initService();
    BackButtonInterceptor.add(backInterceptor);
  }

  //  On some android phones, the back button kills the session :/
  bool backInterceptor(bool stopDefaultButtonEvent, RouteInfo info) {
    Navigator.pop(context);
    return true;
  }

  void initService() async {
    volume = await retrieveSavedBgVolume();
    _dragBgVolumeSubject.add(volume);
    await widget.handler
        .customAction(SET_BG_SOUND_VOL, {SET_BG_SOUND_VOL: volume / 100});
    await _handler.customAction(INIT_BG_SOUND, {INIT_BG_SOUND: ''});
  }

  @override
  Widget build(BuildContext context) {
    _handler = AudioHandlerInheritedWidget.of(context).audioHandler;

    return StreamBuilder(
        stream: Stream.fromFuture(Connectivity()
            .checkConnectivity()), // figure out how to refresh the stream periodically
        builder: (context, snapshot) {
          if (snapshot.hasData) {
            if (snapshot.data == ConnectivityResult.none) {
              isOffline = true;
            }
            return StreamBuilder<dynamic>(
                stream: widget.handler.customEvent.stream,
                initialData: NONE,
                builder: (context, snapshot) {
                  var currentSounds;
                  try {
                    if (snapshot.hasData) {
                      if (snapshot.data.runtimeType.toString() ==
                          '_InternalLinkedHashMap<String, String>') {
                        currentSounds = snapshot.data[SEND_BG_SOUND]
                                .toString()
                                .isNotEmptyAndNotNull()
                            ? snapshot.data[SEND_BG_SOUND]
                            : NONE;
                      } else {
                        // do nothing
                      }
                    }
                  } catch (e) {
                    print(e);
                    currentSounds = NONE;
                  }
                  return DraggableScrollableSheet(
                    expand: false,
                    builder: (BuildContext context,
                        ScrollController scrollController) {
                      return SafeArea(
                        top: true,
                        bottom: false,
                        child: Material(
                            color: MeditoColors.moonlight,
                            child: isOffline
                                ? offlineBackgroundSounds(
                                    currentSounds, scrollController)
                                : onlineBackgroundSounds(
                                    currentSounds, scrollController)),
                      );
                    },
                  );
                });
          } else {
            return Container(); // return a spinner
          }
        });
  }

  Widget onlineBackgroundSounds(
      String currentSounds, ScrollController scrollController) {
    return StreamBuilder<ApiResponse<BackgroundSoundsResponse>>(
        stream: widget.stream,
        initialData: ApiResponse.loading(),
        builder: (context, snapshot) {
          switch (snapshot.data.status) {
            case Status.LOADING:
              return Center(
                  child: const CircularProgressIndicator(
                      backgroundColor: Colors.black,
                      valueColor: AlwaysStoppedAnimation<Color>(
                          MeditoColors.walterWhite)));
              break;
            case Status.COMPLETED:
              var list = snapshot.data.body.data;

              var widgetList = <Widget>[
                Divider(height: 16),
                _getHeader(),
                Divider(height: 16),
                _getVolumeWidget(),
                Divider(height: 16),
                _getNoneListItem(currentSounds)
              ];
              widgetList.addAll(list
                  .map<Widget>((e) =>
                      _getBackgroundSoundListTile(e, currentSounds, context))
                  .toList());

              return ListView(
                  controller: scrollController, children: widgetList);

              break;
            case Status.ERROR:
              return _getErrorWidget();
              break;
          }
          return Container();
        });
  }

  Widget offlineBackgroundSounds(
      String currentSounds, ScrollController scrollController) {
    return FutureBuilder<List<BackgroundSoundData>>(
        future: getBgSoundFromOfflineSharedPrefs(),
        initialData: [],
        builder: (context, snapshot) {
          if (snapshot.hasData) {
            var list = snapshot.data;
            var widgetList = <Widget>[
              Divider(height: 16),
              _getHeader(),
              Divider(height: 16),
              _getVolumeWidget(),
              Divider(height: 16),
              _getNoneListItem(currentSounds)
            ];
            widgetList.addAll(list
                .map((e) =>
                    _getBackgroundSoundListTile(e, currentSounds, context))
                .toList());

            return ListView(controller: scrollController, children: widgetList);
          } else {
            return Center(
                child: const CircularProgressIndicator(
                    backgroundColor: Colors.black,
                    valueColor: AlwaysStoppedAnimation<Color>(
                        MeditoColors.walterWhite)));
          }
        });
  }

  Widget _getErrorWidget() => Padding(
        padding: const EdgeInsets.all(64.0),
        child: Center(child: Text(PLAYER_BG_ERROR_MSG)),
      );

  InkWell _getNoneListItem(currentSounds) {
    return InkWell(
      child: ListTile(
        onTap: _noneSelected,
        title: Text(NONE, style: _getTheme(currentSounds, NONE)),
        trailing: _getVisibilityWidget(
          NONE,
          currentSounds,
          Icon(
            Icons.check_circle_outline,
            color: MeditoColors.walterWhite,
          ),
        ),
      ),
    );
  }

  TextStyle _getTheme(current, String name) {
    return Theme.of(context).textTheme.bodyText2.copyWith(
        fontWeight:
            _isSelected(current, name) ? FontWeight.w600 : FontWeight.normal,
        color: _isSelected(current, name)
            ? MeditoColors.walterWhite
            : MeditoColors.meditoTextGrey);
  }

  Widget _getVisibilityWidget(String name, String current, Widget child) =>
      Visibility(
        visible: _isSelected(current, name),
        child: child,
      );

  bool _isSelected(String current, String name) => current == name;

  Widget _getBackgroundSoundListTile(
      BackgroundSoundData item, String current, BuildContext context) {
    var assetUrl = item.file.toAssetUrl();
    return InkWell(
        onTap: () {
          setState(() {
            _downloadingItem = item.name;
          });

          downloadBGMusicFromURL(assetUrl, item.name).then((filePath) {
            if (filePath == 'Connectivity lost') {
              _downloadingItem = '';
              isOffline = true;
              setState(() {});
              createSnackBar(
                  'Connectivity lost. Displaying offline background sounds.',
                  context);
              _noneSelected();
            }
            _downloadingItem = '';
            addBgSoundSelectionToSharedPrefs(filePath, item.name);
            widget.handler.customAction(PLAY_BG_SOUND, {PLAY_BG_SOUND: filePath});
            return widget.handler.customAction(SEND_BG_SOUND, {SEND_BG_SOUND: item.name});
          });
        },
        child: ListTile(
            enableFeedback: true,
            title: Text('${item.name}', style: _getTheme(current, item.name)),
            trailing: _isDownloading(item)
                ? _getSmallLoadingWidget()
                : _getVisibilityWidget(
                    item.name,
                    current,
                    Icon(
                      Icons.check_circle_outline,
                      color: MeditoColors.walterWhite,
                    ))));
  }

  bool _isDownloading(BackgroundSoundData item) =>
      _downloadingItem == item.name;

  Widget _getSmallLoadingWidget() => Padding(
        padding: const EdgeInsets.only(right: 6.0),
        child: SizedBox(
            height: 16,
            width: 16,
            child: const CircularProgressIndicator(
                backgroundColor: Colors.black,
                valueColor:
                    AlwaysStoppedAnimation<Color>(MeditoColors.walterWhite))),
      );

  void _noneSelected() {
    print('selecting NONE');
    _handler.customAction(SEND_BG_SOUND, {SEND_BG_SOUND: ''});
    _handler.customAction(PLAY_BG_SOUND, {PLAY_BG_SOUND: ''});
    addBgSoundSelectionToSharedPrefs('', '');
  }

  Widget _getHeader() {
    return Padding(
        padding: const EdgeInsets.only(bottom: 8.0, left: 16.0, top: 8.0),
        child: Text(
          BACKGROUND_SOUNDS,
          style: Theme.of(context).textTheme.headline1,
        ));
  }

  Widget _getVolumeWidget() {
    return Container(
      color: MeditoColors.softGrey,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        child: StreamBuilder<Object>(
            stream: _dragBgVolumeSubject,
            builder: (context, snapshot) {
              volume = _dragBgVolumeSubject.value;
              var volumeIcon = _volumeIconFunction(volume);
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(volumeIcon, size: 24, color: MeditoColors.walterWhite),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(left: 24.0, right: 4),
                      child: SliderTheme(
                        data: SliderThemeData(
                          trackShape: CustomTrackShape(addTopPadding: false),
                          thumbShape:
                              RoundSliderThumbShape(enabledThumbRadius: 10.0),
                        ),
                        child: Slider(
                          min: 0.0,
                          activeColor: MeditoColors.walterWhite,
                          inactiveColor:
                              MeditoColors.walterWhite.withOpacity(0.7),
                          max: 100.0,
                          value: volume,
                          onChanged: (value) {
                            _dragBgVolumeSubject.add(value);
                            _handler.customAction(
                                SET_BG_SOUND_VOL, {SET_BG_SOUND_VOL: value / 100});
                          },
                          onChangeEnd: (value) {
                            saveBgVolume(value);
                          },
                        ),
                      ),
                    ),
                  ),
                ],
              );
            }),
      ),
    );
  }

  IconData _volumeIconFunction(var volume) {
    if (volume == 0) {
      return Icons.volume_off;
    } else if (volume < 50) {
      return Icons.volume_down;
    } else {
      return Icons.volume_up;
    }
  }

  @override
  void dispose() {
    BackButtonInterceptor.remove(backInterceptor);
    _dragBgVolumeSubject.close();
    super.dispose();
  }
}
