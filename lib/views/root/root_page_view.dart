import 'dart:async';

import 'package:Medito/constants/constants.dart';
import 'package:Medito/providers/providers.dart';
import 'package:Medito/providers/root/root_combine_provider.dart';
import 'package:Medito/services/notifications/notifications_service.dart';
import 'package:Medito/widgets/widgets.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class RootPageView extends ConsumerStatefulWidget {
  final Widget firstChild;

  RootPageView({required this.firstChild});

  @override
  ConsumerState<RootPageView> createState() => _RootPageViewState();
}

class _RootPageViewState extends ConsumerState<RootPageView> {
  var _isConnected = true;
  late final StreamSubscription<List<ConnectivityResult>> _subscription;

  @override
  void initState() {
    super.initState();
    ref.read(rootCombineProvider(context));
    checkInitialMessage(context, ref);
    _subscription = Connectivity()
        .onConnectivityChanged
        .listen((List<ConnectivityResult> result) {
      _isConnected = !result.contains(ConnectivityResult.none);

      if (!_isConnected) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => ConnectivityErrorWidget()),
        );
      }
    });
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(
      playerProvider,
      (prev, next) {
        var prevId = prev?.audio.first.files.first.id;
        var nextId = next?.audio.first.files.first.id;
        if (next != null &&
            (prev?.id != next.id ||
                (prev?.id == next.id && prevId != nextId))) {
          ref.read(playerProvider.notifier).handleAudioStartedEvent(
                next.audio.first.guideName ?? '',
                next.id,
                next.audio.first.files.first.id,
                next.audio.first.files.first.duration,
              );
        }
      },
    );

    return Scaffold(
      backgroundColor: ColorConstants.black,
      resizeToAvoidBottomInset: false,
      body: NotificationListener<ScrollNotification>(
        child: PageView(
          scrollDirection: Axis.vertical,
          physics: ClampingScrollPhysics(),
          children: [
            Stack(
              alignment: Alignment.bottomCenter,
              children: [
                widget.firstChild,
              ],
            ),
          ],
        ),
      ),
    );
  }
}
