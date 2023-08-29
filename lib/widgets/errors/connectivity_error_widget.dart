import 'package:Medito/constants/constants.dart';
import 'package:Medito/providers/providers.dart';
import 'package:Medito/utils/utils.dart';
import 'package:flutter/material.dart';
import 'package:Medito/widgets/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class ConnectivityErrorWidget extends ConsumerStatefulWidget {
  const ConnectivityErrorWidget({super.key});

  @override
  ConsumerState<ConnectivityErrorWidget> createState() =>
      _ConnectivityErrorComponentState();
}

class _ConnectivityErrorComponentState
    extends ConsumerState<ConnectivityErrorWidget> {
  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    _refreshAPI();
    super.didChangeDependencies();
  }

  void _refreshAPI() {
    var location = GoRouter.of(context).location;
    var id = location.split('/').last;
    var isFolder = location.contains('folder');
    var isMeditation = location.contains('meditation');

    if (isFolder && isMeditation) {
      ref.read(meditationsProvider(meditationId: int.parse(id)));
    } else if (isFolder && !isMeditation) {
      ref.read(FoldersProvider(folderId: int.parse(id)));
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(audioPlayPauseProvider);

    return WillPopScope(
      onWillPop: () async => false,
      child: MeditoErrorWidget(
        onTap: () {
          var connectivityStatus =
              ref.read(connectivityStatusProvider.notifier);
          connectivityStatus.checkConnectivity();
          createSnackBar(
            StringConstants.retrying,
            context,
            color: ColorConstants.darkBGColor,
          );
        },
        message: StringConstants.checkConnection,
        showCheckDownloadText: true,
      ),
    );
  }
}
