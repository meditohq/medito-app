import 'package:flutter/material.dart';
import 'package:Medito/widgets/medito_logo.dart';
import 'package:Medito/utils/colors.dart';

/// @params [onButtonTap] function that will be executed when
/// the error button or the medito logo is tapped
class NetworkErrorWidget extends StatelessWidget {
  final Function onButtonTap;

  const NetworkErrorWidget({
    Key key,
    @required this.onButtonTap,
  }) : super(key: key);
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        MeditoLogo(onDoubleTap: onButtonTap),
        Expanded(
          child: Container(
            child: Align(
              alignment: Alignment.center,
              child: RaisedButton(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: new BorderRadius.circular(16.0),
                ),
                color: MeditoColors.darkColor,
                onPressed: onButtonTap,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    'Oops! There was an error.\n Tap to refresh',
                    style: Theme.of(context).textTheme.bodyText2,
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
          ),
        )
      ],
    );
  }
}
