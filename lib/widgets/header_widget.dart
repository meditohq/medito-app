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

import 'dart:async';

import 'package:Medito/network/api_response.dart';
import 'package:Medito/utils/colors.dart';
import 'package:Medito/utils/utils.dart';
import 'package:Medito/widgets/gradient_widget.dart';
import 'package:Medito/widgets/main/app_bar_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

class HeaderWidget extends StatelessWidget {
  HeaderWidget({
    Key key,
    this.primaryColorController,
    this.titleController,
    this.coverController,
    this.backgroundImageController,
    this.descriptionController,
    this.whiteText = false,
  }) : super(key: key);
  final StreamController<String> primaryColorController;
  final StreamController<String> titleController;
  final StreamController<ApiResponse<String>> coverController;
  final StreamController<String> backgroundImageController;
  final StreamController<String> descriptionController;
  final whiteText;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<String>(
        stream: primaryColorController.stream,
        builder: (context, snapshot) {
          return Container(
            color: MeditoColors.intoTheNight,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Stack(
                  children: [
                    GradientWidget(
                      opacity: 0.32,
                      height: 168.0,
                      primaryColor: snapshot.hasData
                          ? parseColor(snapshot.data)
                          : MeditoColors.transparent,
                    ),
                    Column(
                      mainAxisAlignment: MainAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        MeditoAppBarWidget(transparent: true),
                        _getRow(),
                      ],
                    ),
                  ],
                ),
                _getDescriptionWidget(),
              ],
            ),
          );
        });
  }

  Row _getRow() {
    return Row(
      children: [
        _getImageContainer(size: 96),
        Flexible(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: _getTitleStream(),
          ),
        )
      ],
    );
  }

  Widget _getImageContainer({double size}) {
    return Padding(
      padding: const EdgeInsets.only(left: 16.0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(6.0),
        child: SizedBox(
          height: size,
          width: size,
          child: StreamBuilder<String>(
              stream: primaryColorController.stream,
              builder: (context, snapshot) {
                return Container(
                  color: snapshot.hasData
                      ? parseColor(snapshot.data)
                      : MeditoColors.intoTheNight,
                  child: Stack(
                    children: [
                      _bgImageStream(),
                      _actualImageStream(),
                    ],
                  ),
                );
              }),
        ),
      ),
    );
  }

  StreamBuilder<String> _getTitleStream() => StreamBuilder<String>(
      initialData: '',
      stream: titleController.stream,
      builder: (context, snapshot) {
        return Text(
          snapshot.data,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.headline1,
        );
      });

  StreamBuilder<ApiResponse<String>> _actualImageStream() {
    return StreamBuilder<ApiResponse<String>>(
        stream: coverController.stream,
        initialData: ApiResponse.loading(),
        builder: (context, snapshot) {
          switch (snapshot.data.status) {
            case Status.LOADING:
              return Center(
                child: SizedBox(
                    height: 24,
                    width: 24,
                    child: CircularProgressIndicator(
                      backgroundColor: MeditoColors.transparent,
                      valueColor:
                          AlwaysStoppedAnimation<Color>(MeditoColors.darkMoon),
                    )),
              );
              break;

            case Status.COMPLETED:
              return Padding(
                padding: const EdgeInsets.all(12.0),
                child: getNetworkImageWidget(snapshot.data.body),
              );
              break;
            case Status.ERROR:
              return Center(child: Icon(Icons.broken_image_outlined));
            default:
              return Container();
          }
        });
  }

  Widget _bgImageStream() {
    if (backgroundImageController != null) {
      return StreamBuilder<String>(
          stream: backgroundImageController.stream,
          builder: (context, snapshot) {
            if (snapshot.hasData) {
              return getNetworkImageWidget(snapshot.data);
            } else {
              return Container();
            }
          });
    } else {
      return Container();
    }
  }

  Widget _getDescriptionWidget() {
    return StreamBuilder<String>(
        stream: descriptionController.stream,
        builder: (context, snapshot) {
          if (snapshot.hasData && snapshot.data.isNotEmptyAndNotNull()) {
            return Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
              child: Markdown(
                data: snapshot?.data ?? '',
                onTapLink: _linkTap,
                padding: const EdgeInsets.all(0),
                physics: NeverScrollableScrollPhysics(),
                styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context))
                    .copyWith(
                        p: Theme.of(context).textTheme.subtitle1.copyWith(
                            fontSize: 14.0,
                            color: whiteText
                                ? MeditoColors.walterWhite
                                : MeditoColors.meditoTextGrey)),
                shrinkWrap: true,
              ),
            );
          } else {
            return Container(height: 20);
          }
        });
  }

  void _linkTap(String text, String href, String title) {
    launchUrl(href);
  }
}
