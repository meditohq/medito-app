/*This file is part of Medito App.

Medito App is free software: you can redistribute it and/or modify
it under the terms of the Affero GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

Medito App is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
Affero GNU General Public License for more details.

You should have received a copy of the Affero GNU General Public License
along with Medito App. If not, see <https://www.gnu.org/licenses/>.*/

import 'package:Medito/network/text/text_bloc.dart';
import 'package:Medito/tracking/tracking.dart';
import 'package:Medito/utils/utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:flutter_html/style.dart';
import 'package:Medito/widgets/app_bar_widget.dart';

class TextFileStateless extends StatelessWidget {
  TextFileStateless({Key key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return TextFileWidget();
  }
}

class TextFileWidget extends StatefulWidget {
  TextFileWidget({Key key, this.id}) : super(key: key);

  final String id;

  @override
  _TextFileWidgetState createState() => _TextFileWidgetState();
}

class _TextFileWidgetState extends State<TextFileWidget>
    with TickerProviderStateMixin {
  BuildContext scaffoldContext;
  var _bloc = TextBloc();

  @override
  void dispose() {
    _bloc.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    Tracking.changeScreenName(Tracking.TEXT_PAGE);
    _bloc = TextBloc()..fetchText(widget.id);
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarBrightness: Brightness.dark,
    ));

    return Scaffold(
      body: Builder(
        builder: (BuildContext context) {
          scaffoldContext = context;
          return buildSafeAreaBody();
        },
      ),
    );
  }

  Widget buildSafeAreaBody() {
    return SafeArea(
      bottom: false,
      maintainBottomViewPadding: false,
      child: getInnerTextView(),
    );
  }

  void _linkTap(String url) {
    launchUrl(url);
  }

  Widget getInnerTextView() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.max,
        mainAxisAlignment: MainAxisAlignment.start,
        children: <Widget>[
          StreamBuilder<String>(
              stream: _bloc.titleController.stream,
              initialData: '...',
              builder: (context, snapshot) {
                return MeditoAppBarWidget(
                  title: snapshot.data,
                );
              }),
          Padding(
            padding: const EdgeInsets.only(
                left: 16.0, right: 16.0, top: 12.0, bottom: 16.0),
            child: StreamBuilder<String>(
                stream: _bloc.bodyController.stream,
                initialData: 'Loading...',
                builder: (context, snapshot) {
                  return Html(
                    data: '<p>${snapshot.data}</p>',
                    onLinkTap: _linkTap,
                    shrinkWrap: true,
                    style: {
                      'a': Style(color: Colors.white),
                      'html': Style(fontSize: FontSize(18))
                    },
                  );
                }),
          ),
        ],
      ),
    );
  }
}
