import 'package:flutter/cupertino.dart';

import 'medito_audio_handler.dart';

class AudioHandlerInheritedWidget extends InheritedWidget {
  const AudioHandlerInheritedWidget({
    Key? key,
    required this.audioHandler,
    required Widget child,
  }) : super(key: key, child: child);

  final MeditoAudioHandler audioHandler;

  static AudioHandlerInheritedWidget of(BuildContext context) {
    final result = context
        .dependOnInheritedWidgetOfExactType<AudioHandlerInheritedWidget>();
    assert(result != null, 'No AudioHandler found in context');
    return result!;
  }

  @override
  bool updateShouldNotify(AudioHandlerInheritedWidget old) =>
      audioHandler != old.audioHandler;
}
