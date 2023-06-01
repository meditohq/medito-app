import 'package:Medito/components/components.dart';
import 'package:Medito/constants/constants.dart';
import 'package:Medito/providers/providers.dart';
import 'package:Medito/utils/utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ConnectivityErrorComponent extends ConsumerStatefulWidget {
  const ConnectivityErrorComponent({super.key});

  @override
  ConsumerState<ConnectivityErrorComponent> createState() =>
      _ConnectivityErrorComponentState();
}

class _ConnectivityErrorComponentState
    extends ConsumerState<ConnectivityErrorComponent> {
  @override
  void initState() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(audioPlayPauseStateProvider.notifier).state =
          PLAY_PAUSE_AUDIO.PAUSE;
    });
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(audioPlayPauseProvider);

    return ErrorComponent(
      onTap: () {
        var connectivityStatus = ref.read(connectivityStatusProvider.notifier);
        connectivityStatus.checkConnectivity();
        createSnackBar(
          StringConstants.retrying,
          context,
          color: ColorConstants.darkBGColor,
        );
      },
      message: StringConstants.checkConnection,
    );
  }
}
