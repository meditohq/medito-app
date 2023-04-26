import 'package:Medito/constants/constants.dart';
import 'package:Medito/utils/stats_utils.dart';
import 'package:Medito/providers/stats/stats_provider.dart';
import 'package:Medito/views/home/streak_tile_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pedantic/pedantic.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

class StatsWidget extends ConsumerStatefulWidget {
  @override
  ConsumerState<StatsWidget> createState() => _StatsWidgetState();
}

class _StatsWidgetState extends ConsumerState<StatsWidget> {
  final TextEditingController _controller = TextEditingController();
  @override
  void initState() {
    ref.read(statsProvider);
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 12.0, right: 12.0),
      child: Card(
        color: ColorConstants.deepNight,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16.0)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          child: Table(
            columnWidths: const {
              0: FlexColumnWidth(),
              1: FlexColumnWidth(),
            },
            children: [
              TableRow(children: [
                statsItem(0),
                statsItem(1),
                statsItem(2),
                statsItem(3),
              ]),
            ],
          ),
        ),
      ),
    );
  }

  Widget statsItem(int index) {
    switch (index) {
      case 0:
        return StreakTileWidget(
          getCurrentStreak(),
          'Current\nstreak',
          onClick: openEditDialog,
          editable: true,
          optionalText: UnitType.day,
        );
      case 1:
        return StreakTileWidget(
          getMinutesListened(),
          'Minutes Listened',
          optionalText: UnitType.min,
        );
      case 2:
        return StreakTileWidget(
          getLongestStreak(),
          'Longest\nstreak',
          editable: true,
          onClick: openResetDialog,
          optionalText: UnitType.day,
        );
      case 3:
        return FutureBuilder<String>(
            future: getNumSessions(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.done) {
                return StreakTileWidget(
                  getNumSessions(),
                  snapshot.data == '1'
                      ? 'Session\nListened'
                      : 'Sessions\nListened',
                  optionalText: UnitType.sessions,
                );
              } else {
                return Container();
              }
            });
    }
    return Container();
  }

  void openEditDialog() {
    showDialog(
      barrierDismissible: true,
      context: context,
      builder: (BuildContext context) {
        return Theme(
          data: ThemeData(
            primaryColor: ColorConstants.walterWhite,
          ),
          child: AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            backgroundColor: ColorConstants.moonlight,
            title: Text('How many days is your streak?',
                style: Theme.of(context).textTheme.headline4),
            content: TextField(
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .subtitle2
                  ?.copyWith(letterSpacing: 1.5),
              decoration: InputDecoration(
                  border: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.red))),
              keyboardType: TextInputType.number,
              autofocus: true,
              controller: _controller,
            ),
            actions: <Widget>[
              Padding(
                padding: const EdgeInsets.only(right: 8.0, bottom: 8.0),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: <Widget>[
                    Container(
                      height: 38,
                      child: TextButton(
                        onPressed: _onCancelTap,
                        child: Text('CANCEL',
                            style: Theme.of(context).textTheme.subtitle1
                            // .copyWith(fontWeight: FontWeight.bold),
                            ),
                      ),
                    ),
                    Container(
                      width: 8,
                    ),
                    Container(
                      height: 38,
                      child: TextButton(
                        onPressed: _onSaveTap,
                        style: TextButton.styleFrom(
                            foregroundColor: ColorConstants.walterWhite),
                        child: Text('SAVE',
                            style: Theme.of(context).textTheme.headline3
                            // .copyWith(fontWeight: FontWeight.bold),
                            ),
                      ),
                    ),
                  ],
                ),
              )
            ],
          ),
        );
      },
    ).then((val) {
      setState(() {
        if (val != null) {
          updateStreak(streak: val);
        }
      });
    });
  }

  void openResetDialog() {
    showDialog(
      barrierDismissible: true,
      context: context,
      builder: (BuildContext context) {
        return Theme(
          data: ThemeData(
              primaryColor: ColorConstants.walterWhite,
              hintColor: Colors.green),
          child: AlertDialog(
            backgroundColor: ColorConstants.moonlight,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Text('Reset longest streak to your current streak?',
                style: Theme.of(context).textTheme.headline4),
            actions: <Widget>[
              Padding(
                padding: const EdgeInsets.only(right: 16.0, bottom: 8.0),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: <Widget>[
                    Container(
                      height: 38,
                      child: TextButton(
                        onPressed: _onCancelTap,
                        style: TextButton.styleFrom(
                            foregroundColor: ColorConstants.moonlight),
                        child: Text('CANCEL',
                            style: Theme.of(context).textTheme.subtitle1
                            // .copyWith(fontWeight: FontWeight.bold),
                            ),
                      ),
                    ),
                    Container(
                      width: 8,
                    ),
                    Container(
                      height: 38,
                      child: TextButton(
                        onPressed: _onResetTap,
                        style: TextButton.styleFrom(
                            foregroundColor: ColorConstants.walterWhite),
                        child: Text('RESET',
                            style: Theme.of(context).textTheme.headline3
                            // .copyWith(fontWeight: FontWeight.bold),
                            ),
                      ),
                    ),
                  ],
                ),
              )
            ],
          ),
        );
      },
    );
  }

  void _onResetTap() {
    setLongestStreakToCurrentStreak();
    Navigator.pop(context, _controller.text);
    setState(() {});
  }

  void _onSaveTap() {
    Navigator.pop(context, _controller.text);
    _controller.text = '';
  }

  void _onCancelTap() {
    try {
      Navigator.pop(context);
      _controller.text = '';
    } catch (e, st) {
      unawaited(
        Sentry.captureException(
          e,
          stackTrace: st,
          hint: Hint.withMap(
            {'message': 'cancel stats widget ${_controller.text}'},
          ),
        ),
      );
    }
  }
}
