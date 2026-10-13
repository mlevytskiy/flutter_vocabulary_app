import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/session_source.dart';
import '../../../core/providers.dart';

/// One photo of the photo panel, read from the kept 1600 px file and decoded
/// at [width] × the device pixel ratio, with no stored thumbnail (sad §4
/// "Previews"). The file is read only after the first frame, so the main
/// screen's start does not wait for it (spec §6); a file read before is
/// already in memory ([SourcePhotoBytes]) and shows at once, from the image
/// cache. A missing file or a failed decode shows [placeholder] (spec AC-09);
/// the look gives its own, and [PhotoNotAvailable] is the plain default.
class PhotoPreview extends ConsumerStatefulWidget {
  const PhotoPreview({
    super.key,
    required this.source,
    required this.width,
    this.fit = BoxFit.cover,
    this.placeholder,
  });

  final SessionSource source;

  /// The logical width the photo is drawn at; it decides the decode size.
  final double width;
  final BoxFit fit;
  final WidgetBuilder? placeholder;

  /// The image a preview of [bytes] at [width] draws: the same key in the
  /// image cache, so a photo warmed with it ([precacheImage]) shows at once.
  static ImageProvider imageFor(Uint8List bytes, double width, double dpr) =>
      ResizeImage.resizeIfNeeded((width * dpr).round(), null, MemoryImage(bytes));

  @override
  ConsumerState<PhotoPreview> createState() => _PhotoPreviewState();
}

class _PhotoPreviewState extends ConsumerState<PhotoPreview> {
  /// The read is over, and its bytes (null: no file).
  bool _done = false;
  Uint8List? _data;

  @override
  void initState() {
    super.initState();
    if (!_takeKept()) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _load());
    }
  }

  @override
  void didUpdateWidget(PhotoPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.source.id == widget.source.id) return;
    _done = false;
    _data = null;
    if (!_takeKept()) _load();
  }

  /// Takes bytes read before, if there are any.
  bool _takeKept() {
    final kept = ref.read(sourcePhotoBytesProvider).peek(widget.source);
    if (kept == null) return false;
    _data = kept;
    _done = true;
    return true;
  }

  void _load() {
    if (!mounted) return;
    final source = widget.source;
    ref.read(sourcePhotoBytesProvider).read(source).then((bytes) {
      if (!mounted || widget.source.id != source.id) return;
      setState(() {
        _data = bytes;
        _done = true;
      });
    });
  }

  Widget _placeholder(BuildContext context) =>
      widget.placeholder?.call(context) ?? const PhotoNotAvailable();

  @override
  Widget build(BuildContext context) {
    if (!_done) return const SizedBox.expand();
    final data = _data;
    if (data == null) return _placeholder(context);
    return Image(
      image: PhotoPreview.imageFor(
          data, widget.width, MediaQuery.devicePixelRatioOf(context)),
      fit: widget.fit,
      width: double.infinity,
      height: double.infinity,
      gaplessPlayback: true,
      errorBuilder: (context, _, __) => _placeholder(context),
    );
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
