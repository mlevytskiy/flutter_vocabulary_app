import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/source_photo.dart';
import '../../core/providers.dart';

/// The words table's photo dialog: the same full-screen viewer the shared
/// page opens on a phone (good-looking-web SCR-06) — ‹, "n of m", ›, ×, a
/// swipe between photos, pinch zoom up to 4× and a double tap for 2.5×.
Future<void> showPhotoViewer(BuildContext context, List<SourcePhoto> photos,
    {int initialIndex = 0}) {
  return showGeneralDialog<void>(
    context: context,
    barrierColor: Colors.black,
    barrierDismissible: false,
    barrierLabel: 'Source photos',
    transitionDuration: const Duration(milliseconds: 150),
    pageBuilder: (_, __, ___) =>
        PhotoViewer(photos: photos, initialIndex: initialIndex),
  );
}

class PhotoViewer extends ConsumerStatefulWidget {
  const PhotoViewer({super.key, required this.photos, this.initialIndex = 0});

  final List<SourcePhoto> photos;
  final int initialIndex;

  @override
  ConsumerState<PhotoViewer> createState() => _PhotoViewerState();
}

class _PhotoViewerState extends ConsumerState<PhotoViewer> {
  late final PageController _pages =
      PageController(initialPage: widget.initialIndex);
  late final List<Future<Uint8List?>> _bytes;
  late int _index = widget.initialIndex;

  /// While a photo is zoomed, one finger pans it instead of changing photos.
  bool _zoomed = false;

  @override
  void initState() {
    super.initState();
    final store = ref.read(sourcePhotoStoreProvider);
    _bytes = widget.photos.map(store.read).toList();
  }

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  void _go(int index) => _pages.animateToPage(index,
      duration: const Duration(milliseconds: 250), curve: Curves.easeOut);

  @override
  Widget build(BuildContext context) {
    final count = widget.photos.length;
    return Material(
      color: Colors.black,
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  if (count > 1)
                    _BarButton(
                      label: '‹',
                      tooltip: 'Previous photo',
                      onPressed: _index > 0 ? () => _go(_index - 1) : null,
                    ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Semantics(
                      liveRegion: true,
                      child: Text(
                        '${_index + 1} of $count',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (count > 1)
                    _BarButton(
                      label: '›',
                      tooltip: 'Next photo',
                      onPressed:
                          _index < count - 1 ? () => _go(_index + 1) : null,
                    ),
                  const SizedBox(width: 16),
                  _BarButton(
                    label: '×',
                    tooltip: 'Close the photos',
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _pages,
                itemCount: count,
                physics: _zoomed
                    ? const NeverScrollableScrollPhysics()
                    : const PageScrollPhysics(),
                onPageChanged: (index) => setState(() {
                  _index = index;
                  _zoomed = false;
                }),
                itemBuilder: (_, index) => _ZoomablePhoto(
                  bytes: _bytes[index],
                  onZoomChanged: (zoomed) {
                    if (zoomed != _zoomed) setState(() => _zoomed = zoomed);
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The round ‹ › × buttons of the web dialog's bar.
class _BarButton extends StatelessWidget {
  const _BarButton(
      {required this.label, required this.tooltip, required this.onPressed});

  final String label;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: onPressed == null ? 0.35 : 1,
      child: Tooltip(
        message: tooltip,
        child: SizedBox(
          width: 40,
          height: 40,
          child: OutlinedButton(
            onPressed: onPressed,
            style: OutlinedButton.styleFrom(
              padding: EdgeInsets.zero,
              shape: const CircleBorder(),
              side: const BorderSide(color: Color(0xFF555555)),
              backgroundColor: const Color(0xFF1B1B1B),
              foregroundColor: Colors.white,
              disabledForegroundColor: Colors.white,
            ),
            child: Text(label,
                style: const TextStyle(fontSize: 22, height: 1),
                semanticsLabel: tooltip),
          ),
        ),
      ),
    );
  }
}

/// One photo: pinch zoom 1×–4×, pan while zoomed, double tap 1× ↔ 2.5× at
/// the tapped point. A photo that cannot be read shows the web placeholder.
class _ZoomablePhoto extends StatefulWidget {
  const _ZoomablePhoto({required this.bytes, required this.onZoomChanged});

  final Future<Uint8List?> bytes;
  final ValueChanged<bool> onZoomChanged;

  @override
  State<_ZoomablePhoto> createState() => _ZoomablePhotoState();
}

class _ZoomablePhotoState extends State<_ZoomablePhoto>
    with SingleTickerProviderStateMixin {
  final _transform = TransformationController();
  late final AnimationController _animation;
  Matrix4Tween? _tween;
  Offset _tapAt = Offset.zero;

  @override
  void initState() {
    super.initState();
    _animation = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 200))
      ..addListener(() => _transform.value = _tween!.evaluate(_animation));
    _transform.addListener(_reportZoom);
  }

  @override
  void dispose() {
    _animation.dispose();
    _transform.dispose();
    super.dispose();
  }

  void _reportZoom() =>
      widget.onZoomChanged(_transform.value.getMaxScaleOnAxis() > 1.01);

  void _toggleZoom() {
    final zoomed = _transform.value.getMaxScaleOnAxis() > 1.01;
    const scale = 2.5;
    // Zoom so the tapped point stays under the finger.
    final target = zoomed
        ? Matrix4.identity()
        : (Matrix4.identity()
          ..translateByDouble(
              -_tapAt.dx * (scale - 1), -_tapAt.dy * (scale - 1), 0, 1)
          ..scaleByDouble(scale, scale, 1, 1));
    _tween = Matrix4Tween(begin: _transform.value, end: target);
    _animation.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onDoubleTapDown: (details) => _tapAt = details.localPosition,
      onDoubleTap: _toggleZoom,
      child: InteractiveViewer(
        transformationController: _transform,
        minScale: 1,
        maxScale: 4,
        child: SizedBox.expand(
          child: FutureBuilder<Uint8List?>(
            future: widget.bytes,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const SizedBox.expand();
              }
              final data = snapshot.data;
              return data == null
                  ? const _Placeholder()
                  : Image.memory(data,
                      fit: BoxFit.contain,
                      gaplessPlayback: true,
                      semanticLabel: 'Source photo',
                      errorBuilder: (_, __, ___) => const _Placeholder());
            },
          ),
        ),
      ),
    );
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: FractionallySizedBox(
        widthFactor: 0.8,
        child: AspectRatio(
          aspectRatio: 3 / 4,
          child: Container(
            alignment: Alignment.center,
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFF555555)),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Text('Photo not available',
                style: TextStyle(color: Color(0xFFAAAAAA), fontSize: 13)),
          ),
        ),
      ),
    );
  }
}
