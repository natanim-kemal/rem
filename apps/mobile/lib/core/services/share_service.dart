import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';

enum ShareType { text, media }

class SharedContent {
  final String? text;
  final List<SharedMediaFile> files;
  final ShareType type;

  SharedContent({this.text, this.files = const [], required this.type});
}

class ShareService {
  final StreamController<SharedContent> _controller =
      StreamController.broadcast();
  Stream<SharedContent> get contentStream => _controller.stream;
  StreamSubscription? _mediaSub;

  void initialize() {
    // Listen to all shared content (media + text) while app is in memory
    _mediaSub = ReceiveSharingIntent.instance.getMediaStream().listen(
      (List<SharedMediaFile> value) {
        if (value.isEmpty) return;

        final firstFile = value.first;
        final isTextOrUrl =
            firstFile.type == SharedMediaType.text ||
            firstFile.type == SharedMediaType.url;

        if (isTextOrUrl) {
          _controller.add(
            SharedContent(
              text: firstFile.path,
              type: ShareType.text,
              files: value,
            ),
          );
        } else {
          _controller.add(SharedContent(files: value, type: ShareType.media));
        }
      },
      onError: (err) {
        debugPrint('getMediaStream error: $err');
      },
    );

    // Get initial content when app is opened from terminated state
    ReceiveSharingIntent.instance.getInitialMedia().then((
      List<SharedMediaFile> value,
    ) {
      if (value.isEmpty) return;

      final firstFile = value.first;
      final isTextOrUrl =
          firstFile.type == SharedMediaType.text ||
          firstFile.type == SharedMediaType.url;

      if (isTextOrUrl) {
        _controller.add(
          SharedContent(
            text: firstFile.path,
            type: ShareType.text,
            files: value,
          ),
        );
      } else {
        _controller.add(SharedContent(files: value, type: ShareType.media));
      }

      ReceiveSharingIntent.instance.reset();
    });
  }

  void dispose() {
    _mediaSub?.cancel();
    _controller.close();
  }
}
