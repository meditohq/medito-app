import 'package:flutter/material.dart';

class SongPage extends StatefulWidget {
  @override
  _SongPageState createState() => new _SongPageState();
}

class _SongPageState extends State<SongPage> {
  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        floatingActionButton: FloatingActionButton(
          onPressed: () {
            // Add your onPressed code here!
          },
          child: Icon(Icons.play_arrow),
          backgroundColor: Colors.pink,
        ),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            SizedBox(
              width: double.infinity,
              child: Container(
                color: Colors.blue,
                child: Text("helhelsd sdfsdfsdfsdff sdfsdfssdfdsf"
                    "dfsdfsdf sdfsdfs dfsdfdsf sdfho"),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                child: Container(
                  color: Color(0xff343b43),
                  child: Column(
                    children: <Widget>[
                      Text(
                        body,
                        style: TextStyle(fontSize: 32),
                      ),
                    ],
                  ),
                ),
              ),
            )
          ],
        ),
      ),
    );
  }

  String body = "Cupcake ipsum dolor sit amet jujubes. Bear claw jelly jujubes. Sweet roll halvah topping icing liquorice bear claw halvah chupa chups sesame snaps. Brownie chocolate bar lemon drops pudding tart. Marzipan donut cake jelly beans caramels. Pie donut chocolate cake pie cookie gingerbread bear claw lemon drops. Liquorice jelly toffee pudding halvah powder.\n\nDessert sesame snaps oat cake dessert jujubes croissant lollipop. Jelly beans cake liquorice biscuit cake bonbon marshmallow marzipan. Candy chupa chups jelly-o marshmallow cupcake chocolate cake. \n\nChupa chups topping carrot cake. Tiramisu danish candy cake chupa chups wafer lemon drops. Halvah cake pastry carrot cake. Cotton candy cake fruitcake gummies icing croissant cake. Caramels croissant donut brownie chocolate topping sesame snaps topping. Tootsie roll halvah tiramisu pie. Pastry brownie donut caramels gummies.\n\n Icing jelly beans oat cake oat cake. Cotton candy icing sweet. Candy canes halvah croissant sesame snaps sweet roll lemon drops pudding pastry soufflé. Pudding halvah pudding halvah chocolate cake. Croissant donut gingerbread liquorice toffee. Bear claw sesame snaps halvah marshmallow cake fruitcake sweet roll croissant. Fruitcake donut lollipop dragée. \n\nCotton candy apple pie dessert tiramisu macaroon cheesecake gingerbread sesame snaps gingerbread. Toffee macaroon oat cake candy macaroon jujubes soufflé. Marzipan sugar plum wafer sesame snaps marzipan sweet roll sweet roll cheesecake. Candy cupcake cheesecake chocolate bar liquorice fruitcake sesame snaps jelly-o halvah. Candy canes jujubes soufflé tiramisu danish sweet pudding sweet. Cake cheesecake oat cake tootsie roll cupcake macaroon sugar plum. Jujubes powder apple pie pastry. Cotton candy cupcake chupa chups. Brownie sugar plum topping toffee cookie bonbon chocolate bar chupa chups. Apple pie danish bear claw halvah oat cake cheesecake fruitcake wafer. \n\nJelly gingerbread sweet roll donut brownie cotton candy gingerbread gummi bears. Marshmallow jujubes jelly beans topping muffin. Candy canes macaroon cotton candy cake pudding lollipop toffee icing gingerbread. Lemon drops sesame snaps icing sugar plum sesame snaps. Muffin tiramisu pastry. Caramels carrot cake gummies topping candy.";
}
