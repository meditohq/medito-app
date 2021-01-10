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

import 'package:Medito/tracking/tracking.dart';
import 'package:Medito/utils/utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_bar_widget.dart';

class TextFileStateless extends StatelessWidget {
  TextFileStateless({Key key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return TextFileWidget();
  }
}

class TextFileWidget extends StatefulWidget {
  TextFileWidget(
      {Key key, this.firstId, this.firstTitle, this.text, this.textFuture})
      : super(key: key);

  final String firstId;
  final String text;
  final String firstTitle;
  final Future<String> textFuture;

  @override
  _TextFileWidgetState createState() => _TextFileWidgetState();
}

class _TextFileWidgetState extends State<TextFileWidget>
    with TickerProviderStateMixin {
  String readMoreText = '';
  String textFileFromFuture = '';

  BuildContext scaffoldContext;

  @override
  void dispose() {
    super.dispose();
  }

  @override
  void initState() {
    super.initState();

    Tracking.changeScreenName(Tracking.TEXT_PAGE);

    textFileFromFuture = widget.text ?? '';
    widget.textFuture?.then((onValue) {
      setState(() {
        textFileFromFuture = onValue;
      });
    });
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
    checkConnectivity().then((connected) {
      if (!connected) {
        createSnackBar('Check your connectivity', scaffoldContext);
      }
    });

    return SafeArea(
      bottom: false,
      maintainBottomViewPadding: false,
      child: Stack(
        children: <Widget>[
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                  child: Stack(
                children: <Widget>[
                  getInnerTextView(),
                ],
              )),
            ],
          ),
        ],
      ),
    );
  }

  Widget getInnerTextView() {
    String content;

    return Container(
      child: Row(
        mainAxisSize: MainAxisSize.max,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.max,
                mainAxisAlignment: MainAxisAlignment.start,
                children: <Widget>[
                  MeditoAppBarWidget(
                    title: widget.firstTitle,
                  ),
                  Padding(
                    padding: const EdgeInsets.only(
                        left: 16.0, right: 16.0, top: 12.0, bottom: 16.0),
                    child: getMarkdownBody(content, context),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
