import 'package:Medito/network/api_response.dart';
import 'package:Medito/network/home/daily_message_bloc.dart';
import 'package:Medito/network/home/daily_message_response.dart';
import 'package:Medito/utils/utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

class DailyMessageWidget extends StatelessWidget {
  final _bloc = DailyMessageBloc();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<ApiResponse<DailyMessageResponse>>(
        stream: _bloc.coursesList.stream,
        builder: (context, snapshot) {
          var widget;
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
                    ), // styleSheetTheme: Theme.of(context).textTheme.bodyText1),
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
