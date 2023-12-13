import 'package:Medito/constants/constants.dart';
import 'package:Medito/providers/providers.dart';
import 'package:Medito/utils/utils.dart';
import 'package:Medito/widgets/widgets.dart';
import 'package:flutter/material.dart';
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
    var isTrack = location.contains('track');
    if (isFolder && isTrack) {
      ref.read(tracksProvider(trackId: id));
    } else if (isFolder && !isTrack) {
      ref.read(packProvider(packId: id));
    }
  }

  @override
  Widget build(BuildContext context) {
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
            color: ColorConstants.ebony,
          );
        },
        message: StringConstants.checkConnection,
        showCheckDownloadText: true,
      ),
    );
  }
}
