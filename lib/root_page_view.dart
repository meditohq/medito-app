import 'dart:io';

import 'package:Medito/constants/constants.dart';
import 'package:Medito/models/models.dart';
import 'package:Medito/providers/providers.dart';
import 'package:Medito/services/notifications/notifications_service.dart';
import 'package:Medito/views/player/player_view.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:just_audio/just_audio.dart';
import 'main.dart';
import 'widgets/widgets.dart';
import 'views/player/widgets/mini_player_widget.dart';

class RootPageView extends ConsumerStatefulWidget {
  final Widget firstChild;

  RootPageView({required this.firstChild});

  @override
  ConsumerState<RootPageView> createState() => _RootPageViewState();
}

class _RootPageViewState extends ConsumerState<RootPageView> {
  @override
  void initState() {
    ref.read(audioPlayerNotifierProvider).initAudioHandler();
    ref.read(remoteStatsProvider);
    ref.read(postLocalStatsProvider);
    ref.read(deviceAppAndUserInfoProvider);
    ref.read(pageviewNotifierProvider).addListenerToPage();
    _saveFcmTokenEvent(ref);
    ref
        .read(playerProvider.notifier)
        .getCurrentlyPlayingTrack(isPlayAudio: false);
    _checkNotificationPermission();
    checkInitialMessage(ref);
    var streamEvent = audioHandler.trackAudioPlayer.playerStateStream
        .map((event) => event.processingState)
        .distinct();
    streamEvent.forEach((element) {
      if (element == ProcessingState.completed) {
        _handleAudioCompletion(ref);
      }
    });
    super.initState();
  }

  void _checkNotificationPermission() {
    Future.delayed(Duration(seconds: 4), () {
      checkNotificationPermission().then((value) {
        var checkPermissionStatusInLocalStorage = ref
            .read(sharedPreferencesProvider)
            .getBool(SharedPreferenceConstants.notificationPermission);
        if (Platform.isAndroid &&
            checkPermissionStatusInLocalStorage == null &&
            value == AuthorizationStatus.denied) {
          context.push(RouteConstants.notificationPermissionPath);
        } else if (Platform.isIOS &&
            value == AuthorizationStatus.notDetermined) {
          context.push(RouteConstants.notificationPermissionPath);
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    var connectivityStatus = ref.watch(connectivityStatusProvider);
    final currentlyPlayingSession = ref.watch(playerProvider);
    var radius = Radius.circular(currentlyPlayingSession != null ? 15 : 0);

    return Scaffold(
      backgroundColor: ColorConstants.almostBlack,
      resizeToAvoidBottomInset: false,
      body: NotificationListener<ScrollNotification>(
        onNotification: (scrollNotification) {
          if (scrollNotification is ScrollUpdateNotification &&
              scrollNotification.depth == 0) {
            ref
                .read(pageviewNotifierProvider.notifier)
                .updateScrollProportion(scrollNotification);
          }

          return true;
        },
        child: PageView(
          controller: ref.read(pageviewNotifierProvider).pageController,
          scrollDirection: Axis.vertical,
          children: [
            Column(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.only(
                      bottomLeft: radius,
                      bottomRight: radius,
                    ),
                    child: _renderChild(
                      context,
                      connectivityStatus as ConnectivityStatus,
                    ),
                  ),
                ),
                _miniPlayer(radius, currentlyPlayingSession),
              ],
            ),
            if (currentlyPlayingSession != null)
              PlayerView(
                trackModel: currentlyPlayingSession,
                file: currentlyPlayingSession.audio.first.files.first,
              ),
          ],
        ),
      ),
    );
  }

  Widget _miniPlayer(Radius radius, TrackModel? currentlyPlayingSession) {
    var opacity = ref.watch(pageviewNotifierProvider).scrollProportion;

    if (currentlyPlayingSession != null) {
      return Column(
        children: [
          height8,
          Consumer(builder: (context, ref, child) {
            return ClipRRect(
              borderRadius: BorderRadius.only(
                topLeft: radius,
                topRight: radius,
              ),
              child: AnimatedOpacity(
                duration: Duration(milliseconds: 700),
                opacity: opacity,
                child: MiniPlayerWidget(
                  trackModel: currentlyPlayingSession,
                ),
              ),
            );
          }),
        ],
      );
    }

    return SizedBox();
  }

  Widget _renderChild(BuildContext context, ConnectivityStatus status) {
    var location = GoRouter.of(context).location;
    if (location == RouteConstants.downloadsPath) {
      return widget.firstChild;
    } else if (status == ConnectivityStatus.isDisonnected) {
      return ConnectivityErrorWidget();
    } else {
      return widget.firstChild;
    }
  }

  void _saveFcmTokenEvent(
    WidgetRef ref,
  ) async {
    var token = await requestGenerateFirebaseToken();
    var fcm = SaveFcmTokenModel(fcmToken: token ?? '');
    var event = EventsModel(
      name: EventTypes.saveFcmToken,
      payload: fcm.toJson(),
    );
    ref.read(eventsProvider(event: event.toJson()));
  }

  void _handleAudioCompletion(
    WidgetRef ref,
  ) {
    final audioProvider = ref.read(audioPlayerNotifierProvider);
    var extras = audioHandler.mediaItem.value?.extras;
    if (extras != null) {
      _handleAudioCompletionEvent(
        ref,
        extras['fileId'],
        extras['trackId'],
      );
      audioProvider.seekValueFromSlider(0);
      audioProvider.pause();

      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(audioPlayPauseStateProvider.notifier).state =
            PLAY_PAUSE_AUDIO.PAUSE;
      });
    }
  }

  void _handleAudioCompletionEvent(
    WidgetRef ref,
    String audioFileId,
    String trackId,
  ) {
    var audio = AudioCompletedModel(
      audioFileId: audioFileId,
      trackId: trackId,
    );
    var event = EventsModel(
      name: EventTypes.audioCompleted,
      payload: audio.toJson(),
    );
    ref.read(eventsProvider(event: event.toJson()));
  }
}
