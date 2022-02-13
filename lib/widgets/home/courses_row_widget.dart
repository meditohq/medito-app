import 'package:Medito/network/api_response.dart';
import 'package:Medito/network/home/courses_bloc.dart';
import 'package:Medito/network/home/courses_response.dart';
import 'package:Medito/widgets/home/courses_row_item_widget.dart';
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
  void initState() {
    super.initState();
    _bloc.fetchCourses();
  }

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.only(top: 24.0, left: 16, bottom: 8.0),
        child: Text('Courses', style: Theme.of(context).textTheme.headline3),
      ),
      SizeChangedLayoutNotifier(
        child: StreamBuilder<ApiResponse<CoursesResponse>>(
            stream: _bloc.coursesList.stream,
            initialData: ApiResponse.loading(),
            builder: (context, snapshot) {
              return AnimatedSwitcher(
                duration: Duration(milliseconds: 100),
                child: _buildCoursesRowWidget(snapshot),
              );
            }),
      ),
      SizedBox(height: 24)
    ]);
  }

  Widget _buildCoursesRowWidget(
      AsyncSnapshot<ApiResponse<CoursesResponse>> snapshot) {
    switch (snapshot.data.status) {
      case Status.LOADING:
        return _horizontalCoursesRow(null, ValueKey('CoursesRowLoading'));
      case Status.COMPLETED:
        return _horizontalCoursesRow(snapshot, ValueKey('CoursesRowCompleted'));
      case Status.ERROR:
        return Icon(Icons.error);
      default:
        return Container();
    }
  }

  Widget _horizontalCoursesRow(
      AsyncSnapshot<ApiResponse<CoursesResponse>> snapshot, Key key) {
    var list = <Widget>[Container(width: 16)];
    if (snapshot != null) {
      snapshot.data?.body?.data?.forEach((element) {
        list.add(CoursesRowItemWidget(
          data: element,
          onTap: widget.onTap,
        ));
      });
    } else {
      list.addAll(List.generate(4, (index) {
        return CoursesRowItemWidget.waiting();
      }));
    }

    return SingleChildScrollView(
      key: key,
      scrollDirection: Axis.horizontal,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: list,
      ),
    );
  }
}
