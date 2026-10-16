import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/models/session_source.dart';
import '../../../core/providers.dart';
import '../../../core/services/source_photo_store.dart';

part 'photo_preview.g.dart';

/// One photo of the photo panel, read from the kept 1600 px file and decoded
/// at [width] × the device pixel ratio, with no stored thumbnail (sad §4
/// "Previews"). The file is read only after the first frame, so the main
/// screen's start does not wait for it (spec §6). A missing file or a failed
/// decode shows [placeholder] (spec AC-09); the look gives its own, and
/// [PhotoNotAvailable] is the plain default.
class PhotoPreview extends ConsumerStatefulWidget {
  const PhotoPreview({
    super.key,
    required this.source,
    required this.width,
    this.fit = BoxFit.cover,
    this.placeholder,
    this.preloader,
  });

  final SessionSource source;

  /// The logical width the photo is drawn at; it decides the decode size.
  final double width;
  final BoxFit fit;
  final WidgetBuilder? placeholder;

  /// The panel's photos read ahead; a photo it has read is drawn in the
  /// first frame, with no wait for the file (owner, 2026-10-15).
  final PhotoPreloader? preloader;

  @override
  ConsumerState<PhotoPreview> createState() => _PhotoPreviewState();
}

class _PhotoPreviewState extends ConsumerState<PhotoPreview> {
  Future<Uint8List?>? _bytes;

  @override
  void initState() {
    super.initState();
    if (widget.preloader?.isRead(widget.source) ?? false) {
      _load();
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _load());
    });
  }

  @override
  void didUpdateWidget(PhotoPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.source.id != widget.source.id && _bytes != null) _load();
  }

  void _load() {
    final preloader = widget.preloader;
    _bytes = preloader != null && preloader.isRead(widget.source)
        ? SynchronousFuture(preloader.bytesOf(widget.source))
        : ref.read(sourcePhotoStoreProvider).read(widget.source);
  }

  Widget _placeholder(BuildContext context) =>
      widget.placeholder?.call(context) ?? const PhotoNotAvailable();

  @override
  Widget build(BuildContext context) {
    final bytes = _bytes;
    if (bytes == null) return const SizedBox.expand();
    return FutureBuilder<Uint8List?>(
      future: bytes,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const SizedBox.expand();
        }
        final data = snapshot.data;
        if (data == null) return _placeholder(context);
        final dpr = MediaQuery.devicePixelRatioOf(context);
        return Image.memory(
          data,
          fit: widget.fit,
          width: double.infinity,
          height: double.infinity,
          cacheWidth: previewCacheWidth(widget.width, dpr),
          gaplessPlayback: true,
          errorBuilder: (context, _, __) => _placeholder(context),
        );
      },
    );
  }
}

/// The decode width of a photo drawn at logical [width].
int previewCacheWidth(double width, double devicePixelRatio) =>
    (width * devicePixelRatio).round();

/// The photo panel's read-ahead, shared with the Notes page it opens; it
/// lives while either watches it (owner, 2026-10-15).
@riverpod
PhotoPreloader photoPreloader(Ref ref) => PhotoPreloader();

/// Reads the panel's photos and decodes them at the half-open size, and at
/// the Notes page's size, before the panel opens, and warms a film's poster,
/// so the panel and Notes draw them in their first frame instead of blinking
/// in (owner, 2026-10-15). The bytes live as long as [photoPreloader].
class PhotoPreloader {
  final _read = <String, Uint8List?>{};
  final _started = <String>{};

  /// The photo's file has been read (its bytes may be null: missing).
  bool isRead(SessionSource photo) => _read.containsKey(photo.id);

  Uint8List? bytesOf(SessionSource photo) => _read[photo.id];

  /// Reads each photo of [sources] once and decodes it at each of [widths];
  /// warms each film's poster. Sources no longer listed are dropped.
  void preload(BuildContext context, SourcePhotoStore store,
      List<SessionSource> sources, List<double> widths) {
    final ids = {for (final s in sources) s.id};
    _read.removeWhere((id, _) => !ids.contains(id));
    _started.removeWhere((id) => !ids.contains(id));
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final cacheWidths = {for (final w in widths) previewCacheWidth(w, dpr)};
    for (final source in sources) {
      if (!_started.add(source.id)) continue;
      switch (source.kind) {
        case SourceKind.photo:
          store.read(source).then((bytes) {
            if (!_started.contains(source.id)) return;
            _read[source.id] = bytes;
            if (bytes == null || !context.mounted) return;
            for (final cacheWidth in cacheWidths) {
              precacheImage(
                  ResizeImage(MemoryImage(bytes), width: cacheWidth), context,
                  onError: (_, __) {});
            }
          });
        case SourceKind.subtitles:
          final url = source.url;
          if (url != null && context.mounted) {
            precacheImage(NetworkImage(url), context, onError: (_, __) {});
          }
        case SourceKind.set:
          break;
      }
    }
  }
}

/// The plain "photo not available" placeholder (spec AC-09).
class PhotoNotAvailable extends StatelessWidget {
  const PhotoNotAvailable({super.key});

  @override
  Widget build(BuildContext context) => Semantics(
        label: 'Photo not available',
        child: ColoredBox(
          color: Colors.grey.shade300,
          child: const Center(
            child: Icon(Icons.image_not_supported_outlined, color: Colors.black45),
          ),
        ),
      );
}
