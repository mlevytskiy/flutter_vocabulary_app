import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// The app is portrait only; the story page alone turns (AC-11, ADR-0005).
const appOrientations = [DeviceOrientation.portraitUp];
const storyOrientations = [DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight];

/// A story page of the Learn flow (learn-welcome AC-10, AC-11): the story
/// picture alone, full screen (its captions are in the picture). A tap or a
/// swipe calls [onDone] once.
///
/// Landscape (T14): [onEnter] runs when the page is built for the first time
/// and [onExit] when it goes away, so the screen can turn to landscape here
/// and back to portrait on the next page.
class StoryPage extends StatefulWidget {
  const StoryPage({
    super.key,
    required this.picturePath,
    required this.onDone,
    this.onEnter,
    this.onExit,
  });

  /// The story picture on the phone; null shows the empty page.
  final String? picturePath;
  final VoidCallback onDone;
  final VoidCallback? onEnter;
  final VoidCallback? onExit;

  @override
  State<StoryPage> createState() => _StoryPageState();
}

class _StoryPageState extends State<StoryPage> {
  bool _done = false;

  @override
  void initState() {
    super.initState();
    // The one place the app turns to landscape (ADR-0005); dispose turns back.
    SystemChrome.setPreferredOrientations(storyOrientations);
    widget.onEnter?.call();
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations(appOrientations);
    widget.onExit?.call();
    super.dispose();
  }

  void _next() {
    if (_done) return;
    _done = true;
    widget.onDone();
  }

  @override
  Widget build(BuildContext context) {
    final path = widget.picturePath;
    return GestureDetector(
      key: const ValueKey('flow-story-page'),
      behavior: HitTestBehavior.opaque,
      onTap: _next,
      onHorizontalDragEnd: (_) => _next(),
      onVerticalDragEnd: (_) => _next(),
      child: ColoredBox(
        color: Theme.of(context).colorScheme.scrim,
        child: SizedBox.expand(
          child: path == null
              ? null
              : Image.file(
                  File(path),
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const SizedBox.expand(),
                ),
        ),
      ),
    );
  }
}
