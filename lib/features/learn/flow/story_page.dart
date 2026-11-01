import 'dart:io';

import 'package:flutter/material.dart';

import '../../../core/theme/app_decor.dart';
import 'story_zoom.dart';

export 'story_zoom.dart' show appOrientations, storyOrientations;

/// A story page of the Learn flow (learn-welcome AC-10, AC-11): the story
/// picture (its captions carry the story) fitted to the portrait card, with
/// "Tap to continue" under it. A tap or a vertical swipe calls [onDone] once;
/// a sideways swipe is the pager's (back to the cards seen, or forward past
/// this page, which the flow screen takes as done too).
///
/// Since learn-flow-cards (owner, 2026-11-01) the page stays portrait: its
/// zoom button opens the picture full screen in landscape ([showStoryZoom]),
/// whose cross brings the flow back in portrait on this page; then
/// [onZoomClosed] runs.
///
/// [onEnter] runs when the page is built for the first time and [onExit]
/// when it goes away.
class StoryPage extends StatefulWidget {
  const StoryPage({
    super.key,
    required this.picturePath,
    required this.onDone,
    this.onEnter,
    this.onExit,
    this.onZoomClosed,
  });

  /// The story picture on the phone; null shows the empty page.
  final String? picturePath;
  final VoidCallback onDone;
  final VoidCallback? onEnter;
  final VoidCallback? onExit;
  final VoidCallback? onZoomClosed;

  @override
  State<StoryPage> createState() => _StoryPageState();
}

class _StoryPageState extends State<StoryPage> {
  bool _done = false;

  @override
  void initState() {
    super.initState();
    widget.onEnter?.call();
  }

  @override
  void dispose() {
    widget.onExit?.call();
    super.dispose();
  }

  void _next() {
    if (_done) return;
    _done = true;
    widget.onDone();
  }

  Future<void> _zoom(String path) async {
    await showStoryZoom(context, path);
    if (mounted) widget.onZoomClosed?.call();
  }

  @override
  Widget build(BuildContext context) {
    final path = widget.picturePath;
    final decor = AppDecor.of(context);
    final text = Theme.of(context).textTheme;
    final radius = BorderRadius.circular(decor.wordRowRadius.clamp(0, 16).toDouble());
    return GestureDetector(
      key: const ValueKey('flow-story-page'),
      behavior: HitTestBehavior.opaque,
      onTap: _next,
      onVerticalDragEnd: (_) => _next(),
      child: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                child: DecoratedBox(
                  decoration: BoxDecoration(color: decor.storyFrame, borderRadius: radius),
                  child: SizedBox.expand(
                    child: path == null
                        ? null
                        : Stack(
                            children: [
                              Positioned.fill(
                                child: Center(
                                  child: ClipRRect(
                                    borderRadius: radius,
                                    child: Image.file(
                                      File(path),
                                      fit: BoxFit.contain,
                                      errorBuilder: (_, __, ___) => const SizedBox.expand(),
                                    ),
                                  ),
                                ),
                              ),
                              Positioned(
                                top: 8,
                                right: 8,
                                child: IconButton.filled(
                                  key: const ValueKey('story-zoom-open'),
                                  tooltip: 'Open full screen',
                                  icon: const Icon(Icons.zoom_out_map),
                                  style: IconButton.styleFrom(
                                    backgroundColor: decor.storyFrame.withValues(alpha: 0.6),
                                    foregroundColor: decor.onStoryFrame,
                                    side: BorderSide(color: decor.onStoryFrame.withValues(alpha: 0.35)),
                                  ),
                                  onPressed: () => _zoom(path),
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Text('Tap to continue', style: text.bodySmall?.copyWith(color: decor.muted)),
            ),
          ],
        ),
      ),
    );
  }
}
