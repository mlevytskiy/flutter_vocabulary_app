import 'package:flutter/material.dart';

/// A film's or series' small poster from OpenSubtitles, shown in the subtitle
/// import's dialogs. Nothing while it loads or when there is none, so a
/// missing poster never leaves a broken image.
class SubtitlePoster extends StatelessWidget {
  const SubtitlePoster(this.url, {super.key, this.width = 60, this.height = 90});

  final String? url;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    final url = this.url;
    if (url == null) return const SizedBox.shrink();
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: Image.network(
        url,
        key: const Key('subtitle-poster'),
        width: width,
        height: height,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stack) => const SizedBox.shrink(),
        frameBuilder: (context, child, frame, wasSynchronouslyLoaded) =>
            frame == null && !wasSynchronouslyLoaded ? SizedBox(width: width, height: height) : child,
      ),
    );
  }
}
