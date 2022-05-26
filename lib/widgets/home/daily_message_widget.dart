import 'package:Medito/network/api_response.dart';
import 'package:Medito/network/home/daily_message_bloc.dart';
import 'package:Medito/network/home/daily_message_response.dart';
import 'package:Medito/utils/utils.dart';
import 'package:Medito/widgets/home/daily_message_item_widget.dart';
import 'package:flutter/material.dart';

//This widget is the quote box on the home screen
class DailyMessageWidget extends StatefulWidget {

  @override
  DailyMessageWidgetState createState() => DailyMessageWidgetState();

  DailyMessageWidget({Key key}) : super(key: key);
}

class DailyMessageWidgetState extends State<DailyMessageWidget> {
  final _bloc = DailyMessageBloc();

  void refresh() {
    _bloc.fetchMessage(skipCache: true);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: StreamBuilder<ApiResponse<DailyMessageResponse>>(
          stream: _bloc.coursesList.stream,
          initialData: ApiResponse.loading(),
          builder: (context, snapshot) {
            return AnimatedSwitcher(
              duration: Duration(milliseconds: 100),
              child: _buildDailyMessageItemWidget(snapshot),
            );
          }),
    );
  }

  Widget _buildDailyMessageItemWidget(
      AsyncSnapshot<ApiResponse<DailyMessageResponse>> snapshot) {
    if (!snapshot.hasData ||
        snapshot.data == null ||
        snapshot.data.body == null ||
        snapshot.data.body.body.isEmptyOrNull()) {
      return DailyMessageItemWidget.loading(
          key: ValueKey('DailyMessageLoading'));
    } else {
      switch (snapshot.data.status) {
        case Status.LOADING:
          return DailyMessageItemWidget.loading(
            key: ValueKey('DailyMessageLoading'),
          );
        case Status.COMPLETED:
          return DailyMessageItemWidget(
            data: snapshot.data.body,
            key: ValueKey('DailyMessageCompleted'),
          );
        case Status.ERROR:
        default:
          return Container();
      }
    }
  }
}
