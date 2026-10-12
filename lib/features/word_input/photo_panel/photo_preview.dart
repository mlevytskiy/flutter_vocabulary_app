import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/session_source.dart';
import '../../../core/providers.dart';

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
  });

  final SessionSource source;

  /// The logical width the photo is drawn at; it decides the decode size.
  final double width;
  final BoxFit fit;
  final WidgetBuilder? placeholder;

  @override
  ConsumerState<PhotoPreview> createState() => _PhotoPreviewState();
}

class _PhotoPreviewState extends ConsumerState<PhotoPreview> {
  Future<Uint8List?>? _bytes;

  @override
  void initState() {
    super.initState();
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
    _bytes = ref.read(sourcePhotoStoreProvider).read(widget.source);
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
          cacheWidth: (widget.width * dpr).round(),
          gaplessPlayback: true,
          errorBuilder: (context, _, __) => _placeholder(context),
        );
      },
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
