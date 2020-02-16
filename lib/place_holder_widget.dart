import 'dart:async';
//
//import 'package:flutter/material.dart';
//import 'package:medito/main.dart';
//
//class _PlaceHolderState extends State<MainWidget> {
//  final _viewModel = new SubscriptionViewModelImpl();
//  final controller = TextEditingController();
//  int currentPage = 0;
////  static List<FolderModel> filesList = [];
//
//  final emailAddressController = TextEditingController();
//  final _formKey = GlobalKey<FormState>();
//  final String emailRegex =
//      r"^[a-zA-Z0-9.!#$%&'*+/=?^_`{|}~-]+@[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,253}[a-zA-Z0-9])?(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,253}[a-zA-Z0-9])?)*$";
//
//  @override
//  Widget build(BuildContext context) {
//    // Build a Form widget using the _formKey created above.
//    return SingleChildScrollView(
//      child: Form(
//        key: _formKey,
//        child: Column(
//          crossAxisAlignment: CrossAxisAlignment.start,
//          children: <Widget>[
//            Image.network("https://source.unsplash.com/AvLHH8qYbAI",
//                height: 300, width: double.infinity, fit: BoxFit.fitWidth),
//            Padding(
//              padding: const EdgeInsets.all(16.0),
//              child: Text(
//                  "To make sure we provide the best service possible, we give access to new comers on a daily basis. \n\nEnter your email below and we will let you know when you can access the app.",
//                  style: const TextStyle(
//                      color: const Color(0xff656565),
//                      fontStyle: FontStyle.normal,
//                      fontSize: 16.0)),
//            ),
//            Padding(
//              padding: const EdgeInsets.only(left: 16, right: 16),
//              child: TextFormField(
//                decoration: InputDecoration(
//                    focusedBorder: OutlineInputBorder(
//                      borderSide: BorderSide(color: Colors.black, width: 1.0),
//                    ),
//                    border: OutlineInputBorder(
//                      borderSide: BorderSide(color: Colors.grey, width: 1.0),
//                    ),
//                    hintText: 'email address'),
//                keyboardType: TextInputType.emailAddress,
//                validator: (value) {
//                  if (!RegExp(emailRegex).hasMatch(value)) {
//                    return "Please enter a valid email address";
//                  }
//                  if (value.isEmpty) {
//                    return 'Please enter your emaill address';
//                  }
//                  return null;
//                },
//              ),
//            ),
//            Padding(
//              padding: const EdgeInsets.only(left: 16, right: 16, top: 4),
//              child: Text("* We’ll never share your email address",
//                  style: const TextStyle(
//                      fontStyle: FontStyle.normal, fontSize: 10.0)),
//            ),
//            Padding(
//              padding: const EdgeInsets.all(16),
//              child: FlatButton(
//                textColor: Colors.white,
//                color: Colors.black,
//                onPressed: () {
//                  // Validate returns true if the form is valid, or false
//                  // otherwise.
//                  if (_formKey.currentState.validate()) {
//                    // If the form is valid, display a Snackbar.
//                    _fire();
//                    Scaffold.of(context).showSnackBar(
//                        SnackBar(content: Text('Subscribing...')));
//                  }
//                },
//                child: Text(
//                  'JOIN WAITING LIST',
//                  style: TextStyle(fontWeight: FontWeight.w600),
//                ),
//              ),
//            ),
//          ],
//        ),
//      ),
//    );
//  }
//
//  void _fire() {
////    Api.updateSubscribers(emailAddressController.text)
////        .whenComplete(_doneSnackBar);
//  }
//
//  FutureOr _doneSnackBar() {
//    Scaffold.of(context).showSnackBar(SnackBar(
//      content: Text('Complete. Thanks!'),
//      backgroundColor: Colors.green,
//    ));
//  }
//}
