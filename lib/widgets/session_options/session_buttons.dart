import 'package:flutter/widgets.dart';

class SessionButtons extends StatefulWidget {
  const SessionButtons({Key? key}) : super(key: key);

  @override
  State<SessionButtons> createState() => _SessionButtonsState();
}

class _SessionButtonsState extends State<SessionButtons> {
  List<Map<String, List<String>>> data = [
    {
      'Will': ['5 mins', '10 min']
    },
    {
      'Bob': ['5 mins', '10 min', '15 min']
    },
    {
      'Steve': ['5 mins', '10 min', '15 min', '40 min']
    }
  ];

  @override
  Widget build(BuildContext context) {
    List<Widget> titles =
        data.map((e) => e.keys).map((e) => Text(e.first)).toList();
    var lengths = data.map((e) => e.values.toList());
    var views = lengths
        .map((e) => e.map((times) => Column(children: times.map((time) => Text(time)).toList())).toList())
        .toList();
    print(views);

    return ListView.builder(
      shrinkWrap: true,
      itemCount: views.length,
      itemBuilder: (context, i) {
        return Column(
          children: [
            titles[i],
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(children: views.toList()[i]),
            ),
          ],
        );
      }
    );
  }
}
