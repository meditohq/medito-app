import 'package:Medito/network/home/courses_response.dart';
import 'package:Medito/constants/constants.dart';
import 'package:Medito/utils/utils.dart';
import 'package:Medito/views/home/loading_text_box_widget.dart';
import 'package:flutter/material.dart';

class CoursesRowItemWidget extends StatelessWidget {
  const CoursesRowItemWidget({required this.data, Key? key, this.onTap})
      : super(key: key);

  final void Function(String?, String?)? onTap;

  final Data? data;

  factory CoursesRowItemWidget.waiting({Key? key}) {
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
    return data != null
        ? Text(
            data?.subtitle ?? '',
            style: Theme.of(context).textTheme.titleMedium,
          )
        : Container(height: 0, width: 0);
  }

  Widget _createTitle(BuildContext context) {
    return data != null
        ? Text(
            data?.title ?? '',
            style: Theme.of(context).textTheme.headlineMedium,
          )
        : LoadingTextBoxWidget(height: 42);
  }

  void Function() _createOnTap() {
    return data != null && onTap != null
        ? () => onTap!(data?.type, data?.id)
        : () => {};
  }

  Widget _imageStack() {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration:
          BoxDecoration(borderRadius: BorderRadius.all(Radius.circular(2))),
      child: Stack(
        children: [
          SizedBox(width: 132, height: 132, child: _buildCardBackground()),
          Positioned.fill(
            child: Center(
              child: SizedBox(
                width: 92,
                height: 92,
                child: _getNetworkImageWidget(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _getNetworkImageWidget() {
    return data != null
        ? getNetworkImageWidget(data?.coverUrl)
        : Container(color: ColorConstants.moonlight);
  }

  Widget _buildCardBackground() {
    if (data != null) {
      return _isBgImageUnavailable()
          ? Container(color: _getColor())
          : getNetworkImageWidget(data?.backgroundImageUrl);
    }

    return Container(color: ColorConstants.moonlight);
  }

  bool _isBgImageUnavailable() => data?.backgroundImage.isNullOrEmpty() == true;

  Color _getColor() {
    return data?.colorPrimary.isNullOrEmpty() == true
        ? ColorConstants.moonlight
        : parseColor(data?.colorPrimary);
  }
}
