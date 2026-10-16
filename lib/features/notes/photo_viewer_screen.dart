import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/session_source.dart';
import '../word_input/photo_panel/photo_preview.dart';
import '../word_input/photo_panel/source_hero.dart';
import '../word_input/word_input_notifier.dart';

/// A source's photo on its own, as large as the screen allows, opened from
/// its picture on the Notes page (notes-editing, owner 2026-10-15). Pinch
/// or double-tap zooms; Back returns to Notes.
class PhotoViewerScreen extends ConsumerStatefulWidget {
  const PhotoViewerScreen({super.key, required this.sourceId});

  final String sourceId;

  static const viewerKey = Key('photo-viewer');

  /// The kept photo's largest side (`PhotoScaler`): decoded at it, so a zoom
  /// shows every pixel there is.
  static const _keptWidth = 1600.0;

  /// Decodes [source]'s photo at the viewer's size from the bytes the panel
  /// already read, so the viewer and its hero draw it in their first frame
  /// (owner, 2026-10-15: no blink). Done when it is in the image cache;
  /// nothing to do for a photo the panel has not read.
  static Future<void> precache(BuildContext context, SessionSource source,
      PhotoPreloader preloader) async {
    final bytes = preloader.bytesOf(source);
    if (bytes == null) return;
    final width = previewCacheWidth(
        _keptWidth / MediaQuery.devicePixelRatioOf(context),
        MediaQuery.devicePixelRatioOf(context));
    await precacheImage(ResizeImage(MemoryImage(bytes), width: width), context,
        onError: (_, __) {});
  }

  @override
  ConsumerState<PhotoViewerScreen> createState() => _PhotoViewerScreenState();
}

class _PhotoViewerScreenState extends ConsumerState<PhotoViewerScreen> {
  final _transform = TransformationController();
  TapDownDetails? _doubleTap;

  @override
  void dispose() {
    _transform.dispose();
    super.dispose();
  }

  /// Zooms in 2.5x around the tapped point, or back out.
  void _toggleZoom() {
    if (_transform.value.getMaxScaleOnAxis() > 1.01) {
      _transform.value = Matrix4.identity();
      return;
    }
    final at = _doubleTap?.localPosition ?? Offset.zero;
    const scale = 2.5;
    _transform.value = Matrix4.identity()
      ..translateByDouble(-at.dx * (scale - 1), -at.dy * (scale - 1), 0, 1)
      ..scaleByDouble(scale, scale, 1, 1);
  }

  @override
  Widget build(BuildContext context) {
    final source = ref
        .watch(wordInputNotifierProvider)
        .valueOrNull
        ?.sources
        .where((s) => s.id == widget.sourceId)
        .firstOrNull;
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final preloader = ref.watch(photoPreloaderProvider);
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.black38,
        foregroundColor: Colors.white,
        elevation: 0,
        title: source?.title == null ? null : Text(source!.title!),
      ),
      body: source == null
          ? const Center(child: PhotoNotAvailable())
          : GestureDetector(
              onDoubleTapDown: (details) => _doubleTap = details,
              onDoubleTap: _toggleZoom,
              child: InteractiveViewer(
                key: PhotoViewerScreen.viewerKey,
                transformationController: _transform,
                minScale: 1,
                maxScale: 6,
                child: Center(
                  child: SourceHero(
                    id: source.id,
                    child: PhotoPreview(
                      source: source,
                      width: PhotoViewerScreen._keptWidth / dpr,
                      fit: BoxFit.contain,
                      // The panel's bytes, decoded ahead by [precache].
                      preloader: preloader,
                    ),
                  ),
                ),
              ),
            ),
    );
  }
}
