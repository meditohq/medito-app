import 'package:Medito/network/home/courses_response.dart';
import 'package:Medito/utils/colors.dart';
import 'package:Medito/utils/utils.dart';
import 'package:Medito/widgets/home/loading_text_box_widget.dart';
import 'package:flutter/material.dart';

class CoursesRowItemWidget extends StatelessWidget {
  const CoursesRowItemWidget({@required this.data, Key key, this.onTap})
      : super(key: key);

  final void Function(dynamic, dynamic) onTap;

  final Data data;

  factory CoursesRowItemWidget.waiting({Key key}) {
    return CoursesRowItemWidget(
      data: null,
      key: key,
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _createOnTap(),
      child: Container(
        width: 148,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _imageStack(),
            Container(height: 8),
            Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: _createTitle(context),
            ),
            Container(height: 2),
            Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: _createSubtitle(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _createSubtitle(BuildContext context) {
    if (data != null) {
      return Text(data.subtitle, style: Theme.of(context).textTheme.subtitle1);
    } else {
      return Container(height: 0, width: 0); //LoadingTextBoxWidget(height: 21);
    }
  }

  Widget _createTitle(BuildContext context) {
    if (data != null) {
      return Text(data.title, style: Theme.of(context).textTheme.headline4);
    } else {
      return LoadingTextBoxWidget(height: 42);
    }
  }

  void Function() _createOnTap() {
    if (data != null && onTap != null) {
      return () => onTap(data.type, data.id);
    } else {
      return () {};
    }
  }

  Widget _imageStack() {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
          borderRadius: BorderRadius.all(Radius.circular(2))),
      child: Stack(
        children: [
          SizedBox(width: 132, height: 132, child: _buildCardBackground()),
          Positioned.fill(
            child: Center(
              child: SizedBox(
                  width: 92, height: 92, child: _getNetworkImageWidget()),
            ),
          ),
        ],
      ),
    );
  }

  Widget _getNetworkImageWidget() {
    if (data != null) {
      return getNetworkImageWidget(data.coverUrl);
    } else {
      return Container(
        color: MeditoColors.moonlight,
      );
    }
  }

  Widget _buildCardBackground() {
    if (data != null) {
      return data.backgroundImage.isEmptyOrNull()
          ? Container(
              color: data.colorPrimary.isEmptyOrNull()
                  ? MeditoColors.moonlight
                  : parseColor(data.colorPrimary))
          : getNetworkImageWidget(data.backgroundImageUrl);
    } else {
      return Container(
        color: MeditoColors.moonlight,
      );
    }
  }
}
