import 'package:Medito/network/api_response.dart';
import 'package:Medito/network/home/courses_bloc.dart';
import 'package:Medito/network/home/courses_response.dart';
import 'package:Medito/utils/colors.dart';
import 'package:Medito/utils/utils.dart';
import 'package:flutter/material.dart';

class CoursesRowWidget extends StatefulWidget {
  @override
  CoursesRowWidgetState createState() => CoursesRowWidgetState();

  CoursesRowWidget({Key key, this.onTap}) : super(key: key);

  final void Function(dynamic, dynamic) onTap;
}

class CoursesRowWidgetState extends State<CoursesRowWidget> {
  final _bloc = CoursesBloc();

  void refresh() {
    _bloc.fetchCourses(skipCache: true);
  }

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.only(top: 32.0, left: 16, bottom: 8.0),
        child: Text('Courses', style: Theme.of(context).textTheme.headline3),
      ),
      SizeChangedLayoutNotifier(
        child: StreamBuilder<ApiResponse<CoursesResponse>>(
            stream: _bloc.coursesList.stream,
            initialData: ApiResponse.loading(),
            builder: (context, snapshot) {
              switch (snapshot.data.status) {
                case Status.LOADING:
                  return _getLoadingWidget();
                  break;
                case Status.COMPLETED:
                  return _horizontalCoursesRow(snapshot);

                  break;
                case Status.ERROR:
                  return Icon(Icons.error);
                  break;
              }
              return Container();
            }),
      ),
    ]);
  }

  Widget _horizontalCoursesRow(
      AsyncSnapshot<ApiResponse<CoursesResponse>> snapshot) {
    var list = <Widget>[Container(width: 16)];
    snapshot.data?.body?.data?.forEach((element) {
      list.add(CoursesRowItemWidget(
        element,
        onTap: widget.onTap,
      ));
    });

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: list,
      ),
    );
  }

  Widget _getLoadingWidget() => Row(
        children: [
          Container(width: 16),
          Container(color: MeditoColors.moonlight, height: 132, width: 132),
          Container(width: 16),
          Container(color: MeditoColors.moonlight, height: 132, width: 132),
        ],
      );
}

class CoursesRowItemWidget extends StatelessWidget {
  const CoursesRowItemWidget(this.data, {Key key, this.onTap})
      : super(key: key);

  final void Function(dynamic, dynamic) onTap;

  final Data data;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onTap(data.type, data.id),
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
              child: Text(
                data.title,
                style: Theme.of(context).textTheme.headline4,
              ),
            ),
            Container(height: 2),
            Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: Text(data.subtitle,
                  style: Theme.of(context).textTheme.subtitle1),
            ),
          ],
        ),
      ),
    );
  }

  Stack _imageStack() {
    return Stack(
      children: [
        SizedBox(width: 132, height: 132, child: _buildCardBackground()),
        Positioned.fill(
          child: Center(
            child: SizedBox(
                width: 92,
                height: 92,
                child: getNetworkImageWidget(data.coverUrl)),
          ),
        ),
      ],
    );
  }

  Widget _buildCardBackground() => data.backgroundImage.isEmptyOrNull()
      ? Container(
          color: data.colorPrimary.isEmptyOrNull()
              ? MeditoColors.moonlight
              : parseColor(data.colorPrimary))
      : getNetworkImageWidget(data.backgroundImageUrl);
}
