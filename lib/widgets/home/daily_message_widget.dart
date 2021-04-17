import 'package:Medito/network/api_response.dart';
import 'package:Medito/network/home/daily_message_bloc.dart';
import 'package:Medito/network/home/daily_message_response.dart';
import 'package:Medito/utils/text_themes.dart';
import 'package:Medito/utils/utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

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
    return StreamBuilder<ApiResponse<DailyMessageResponse>>(
        stream: _bloc.coursesList.stream,
        builder: (context, snapshot) {
          var widget;

          if (!snapshot.hasData) {
            return Container();
          }

          switch (snapshot.data.status) {
            case Status.LOADING:
              widget = const CircularProgressIndicator();
              break;
            case Status.COMPLETED:
              widget = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(snapshot.data.body.title,
                      style: Theme.of(context).textTheme.headline3),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: MarkdownBody(
                      data: snapshot.data.body.body,
                      onTapLink: launchUrl,
                      styleSheet: buildMarkdownStyleSheet(context),
                    ),
                  ),
                ],
              );
              break;
            case Status.ERROR:
              widget = Container();
              break;
          }

          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: widget,
          );
        });
  }
}
