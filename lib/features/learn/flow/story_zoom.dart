import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_decor.dart';

/// The app is portrait only; the story zoom alone turns (learn-welcome AC-11,
/// ADR-0005; since learn-flow-cards, owner 2026-11-01, the zoom and not the
/// story page).
const appOrientations = [DeviceOrientation.portraitUp];
const storyOrientations = [DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight];

/// Opens the story picture at [path] full screen in landscape over the flow
/// (learn-flow-cards). A dialog, not a route: the flow stays below it on the
/// same page. Completes once it is closed and the screen is back to portrait.
Future<void> showStoryZoom(BuildContext context, String path) => showGeneralDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: AppDecor.of(context).storyFrame,
      transitionDuration: const Duration(milliseconds: 220),
      transitionBuilder: (context, animation, _, child) => FadeTransition(opacity: animation, child: child),
      pageBuilder: (context, _, __) => StoryZoomView(picturePath: path),
    );

/// The story picture alone, full screen, in landscape: pinch to zoom, a
/// round cross closes it. The screen turns to landscape when it opens and
/// back to portrait however it closes (the cross or Back).
class StoryZoomView extends StatefulWidget {
  const StoryZoomView({super.key, required this.picturePath});

  final String picturePath;

  @override
  State<StoryZoomView> createState() => _StoryZoomViewState();
}

class _StoryZoomViewState extends State<StoryZoomView> {
  @override
  void initState() {
    super.initState();
    // The one place the app turns to landscape (ADR-0005); dispose turns back.
    SystemChrome.setPreferredOrientations(storyOrientations);
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations(appOrientations);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final decor = AppDecor.of(context);
    // Turn back as soon as it closes (the cross or Back), not after the fade.
    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) SystemChrome.setPreferredOrientations(appOrientations);
      },
      child: Material(
        key: const ValueKey('story-zoom'),
        color: decor.storyFrame,
        child: Stack(
          children: [
            Positioned.fill(
              child: InteractiveViewer(
                maxScale: 4,
                child: Center(
                  child: Image.file(
                    File(widget.picturePath),
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const SizedBox.expand(),
                  ),
                ),
              ),
            ),
            SafeArea(
              child: Align(
                alignment: Alignment.topRight,
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: IconButton.filled(
                    key: const ValueKey('story-zoom-close'),
                    tooltip: 'Close',
                    icon: const Icon(Icons.close),
                    style: IconButton.styleFrom(
                      backgroundColor: decor.storyFrame.withValues(alpha: 0.6),
                      foregroundColor: decor.onStoryFrame,
                      side: BorderSide(color: decor.onStoryFrame.withValues(alpha: 0.35)),
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
