import 'package:Medito/network/home/daily_message_response.dart';
import 'package:Medito/utils/colors.dart';
import 'package:Medito/utils/utils.dart';
import 'package:Medito/widgets/home/loading_text_box_widget.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:share/share.dart';

class DailyMessageItemWidget extends StatelessWidget {
  final DailyMessageResponse data;

  DailyMessageItemWidget({Key key, @required this.data}) : super(key: key);

  factory DailyMessageItemWidget.loading({Key key}) {
    return DailyMessageItemWidget(
      data: null,
      key: key,
    );
  }

  @override
  Widget build(BuildContext context) {
    return SizeChangedLayoutNotifier(
      child: Card(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        color: MeditoColors.deepNight,
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: GestureDetector(
            onTap: _createShareAction(data),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildTitle(context),
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: _buildMarkdownBody(context),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMarkdownBody(BuildContext context) {
    if (data != null) {
      return MarkdownBody(
        data: data.body,
        onTapLink: _launchUrl,
        styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context))
            .copyWith(p: Theme.of(context).textTheme.bodyText1),
      );
    } else {
      return LoadingTextBoxWidget(height: 60);
    }
  }

  Widget _buildTitle(BuildContext context) {
    if (data != null) {
      return Text(data.title.toUpperCase(), style: Theme.of(context).textTheme.subtitle2);
    } else {
      return LoadingTextBoxWidget(height: 23);
    }
  }

  Future<void> Function() _createShareAction(DailyMessageResponse data) {
    if (data != null) {
      return () => Share.share('${data.body} https://medito.app');
    } else {
      return () async {};
    }
  }

  void _launchUrl(String text, String href, String title) {
    launchUrl(href);
  }
}
