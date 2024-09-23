import 'dart:async';

import 'package:medito/constants/constants.dart';
import 'package:medito/providers/player/player_provider.dart';
import 'package:medito/utils/utils.dart';
import 'package:medito/widgets/widgets.dart';
import 'package:medito/routes/routes.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ConnectivityErrorWidget extends ConsumerStatefulWidget {
  const ConnectivityErrorWidget({super.key});

  @override
  ConsumerState<ConnectivityErrorWidget> createState() =>
      _ConnectivityErrorComponentState();
}

class _ConnectivityErrorComponentState
    extends ConsumerState<ConnectivityErrorWidget> {
  var _isConnected = true;
  late final StreamSubscription _subscription;

  @override
  void initState() {
    super.initState();
    _subscription = Connectivity()
        .onConnectivityChanged
        .listen((List<ConnectivityResult> result) {
      setState(() {
        _isConnected = !result.contains(ConnectivityResult.none);
      });
    });
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    _refreshAPI();
    super.didChangeDependencies();
  }

  void _refreshAPI() {
    var currentlyPlayingTrack = ref.watch(playerProvider);
    var id = currentlyPlayingTrack?.id;

    handleNavigation(TypeConstants.pack, [id], context, ref: ref);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: MeditoErrorWidget(
        onTap: () {
          if (_isConnected) {
            _refreshAPI();
            createSnackBar(
              StringConstants.retrying,
              context,
              color: ColorConstants.ebony,
            );
          } else {
            createSnackBar(
              StringConstants.connectivityError,
              context,
              color: ColorConstants.ebony,
            );
          }
        },
        message: StringConstants.checkConnection,
        shouldShowCheckDownloadButton: true,
      ),
    );
  }
}
