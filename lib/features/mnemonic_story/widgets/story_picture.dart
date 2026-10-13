import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';

/// A story run's picture from the phone's picture store, zoomable, 40 % of
/// the screen tall. Cut from the story screen so the dialogue pages show a
/// scene picture the same way (get-words-from-subtitles-improvment).
class StoryPicture extends ConsumerWidget {
  const StoryPicture({super.key, required this.runId, required this.attempt});

  final String runId;
  final int attempt;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.4,
      width: double.infinity,
      child: ClipRect(
        child: InteractiveViewer(
          minScale: 1,
          maxScale: 4,
          child: FutureBuilder<Uint8List?>(
            future: ref
                .read(storyPictureStoreProvider)
                .read(runId, attempt),
            builder: (context, snapshot) {
              final bytes = snapshot.data;
              return bytes == null
                  ? const SizedBox.expand()
                  : Image.memory(bytes,
                      fit: BoxFit.contain, width: double.infinity);
            },
          ),
        ),
      ),
    );
  }
}
