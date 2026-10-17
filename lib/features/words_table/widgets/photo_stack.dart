import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/models/session_source.dart';
import '../../../core/providers.dart';

/// Up to three of the kept photos as small stacked thumbnails, the way the
/// shared page's photo button shows them.
class PhotoStack extends ConsumerStatefulWidget {
  const PhotoStack({super.key, required this.photos});

  final List<SessionSource> photos;

  @override
  ConsumerState<PhotoStack> createState() => _PhotoStackState();
}

class _PhotoStackState extends ConsumerState<PhotoStack> {
  static const _size = 40.0;
  static const _turns = [-7.0, 5.0, 0.0];

  late List<Future<Uint8List?>> _bytes;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(PhotoStack oldWidget) {
    super.didUpdateWidget(oldWidget);
    final ids = widget.photos.map((p) => p.id).join(',');
    if (ids != oldWidget.photos.map((p) => p.id).join(',')) _load();
  }

  void _load() {
    final store = ref.read(sourcePhotoStoreProvider);
    _bytes = widget.photos.take(3).map(store.read).toList();
  }

  @override
  Widget build(BuildContext context) {
    final stacked = _bytes.length > 1;
    return SizedBox(
      width: _size,
      height: _size,
      child: Stack(
        children: [
          for (final (i, bytes) in _bytes.indexed)
            Transform.rotate(
              angle: stacked ? _turns[i] * math.pi / 180 : 0,
              child: _thumb(context, bytes),
            ),
        ],
      ),
    );
  }

  Widget _thumb(BuildContext context, Future<Uint8List?> bytes) => Container(
        width: _size,
        height: _size,
        decoration: BoxDecoration(
          color: AppDecor.of(context).thumb,
          border: Border.all(color: Colors.white, width: 2),
          borderRadius: BorderRadius.circular(8),
          boxShadow: const [
            BoxShadow(
                color: Colors.black38, blurRadius: 4, offset: Offset(0, 1)),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: FutureBuilder<Uint8List?>(
            future: bytes,
            builder: (context, snapshot) {
              final data = snapshot.data;
              return data == null
                  ? const SizedBox.expand()
                  : Image.memory(data,
                      fit: BoxFit.cover,
                      cacheWidth: 120,
                      gaplessPlayback: true,
                      errorBuilder: (_, __, ___) => const SizedBox.expand());
            },
          ),
        ),
      );
}
