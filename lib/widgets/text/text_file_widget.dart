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
import 'package:Medito/utils/colors.dart';
import 'package:Medito/utils/text_themes.dart';
import 'package:Medito/utils/utils.dart';
import 'package:Medito/widgets/main/app_bar_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

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
    _bloc = TextBloc()..fetchText(widget.id, false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size(double.infinity, kToolbarHeight),
        child: StreamBuilder<String>(
            stream: _bloc.titleController.stream,
            initialData: '...',
            builder: (context, snapshot) {
              return MeditoAppBarWidget(
                transparent: true,
                title: snapshot.data,
              );
            }), // StreamBuilder
      ),
      body: RefreshIndicator(
        onRefresh: () => _bloc.fetchText(widget.id, true),
        child: Builder(
          builder: (BuildContext context) {
            scaffoldContext = context;
            return buildSafeAreaBody();
          },
        ),
      ),
    );
  }

  Widget buildSafeAreaBody() {
    return SafeArea(
      bottom: false,
      maintainBottomViewPadding: false,
      child: _getInnerTextView(),
    );
  }

  void _linkTap(String text, String href, String title) {
    launchUrl(href);
  }

  Widget _getInnerTextView() {
    return SingleChildScrollView(
      physics: AlwaysScrollableScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.max,
        mainAxisAlignment: MainAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.only(
                left: 16.0, right: 16.0, top: 12.0, bottom: 16.0),
            child: StreamBuilder<String>(
                stream: _bloc.bodyController.stream,
                initialData: 'Loading...',
                builder: (context, snapshot) {
                  return Markdown(
                      data: snapshot.data,
                      onTapLink: _linkTap,
                      physics: NeverScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(0),
                      shrinkWrap: true,
                      selectable: true,
                      styleSheet: buildMarkdownStyleSheet(context).copyWith(
                          horizontalRuleDecoration: BoxDecoration(
                            border: Border(
                              top: BorderSide(
                                width: 1.0,
                                color: MeditoColors.meditoTextGrey,
                              ),
                            ),
                          ),
                          h2: TextStyle(
                              color: MeditoColors.walterWhite, height: 1.5),
                          p: TextStyle(
                              color: MeditoColors.walterWhite, height: 1.5)));
                }),
          ),
        ],
      ),
    );
  }
}
