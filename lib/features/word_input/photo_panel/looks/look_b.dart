import 'package:flutter/material.dart';

import '../photos_with_words.dart';
import 'photo_panel_look.dart';

/// Design variant B: a slim pill tab with a fan of overlapping round
/// previews and the count on top, a light column of full-width small photos
/// with a coloured bar on the selected one, a full-open that scrolls the
/// large photos up and down as one list, a left accent bar on highlighted
/// rows, and a tab that fades while the word list scrolls.
class LookB extends PhotoPanelLook {
  const LookB();

  static const _mini = 30.0;
  static const _overlap = 12.0;
  static const _countHeight = 26.0;

  @override
  double get tabWidth => 40;

  @override
  double tabHeight(int count) {
    final shown = count.clamp(1, 3);
    return 8 + _countHeight + _mini + (shown - 1) * (_mini - _overlap) + 10;
  }

  @override
  Widget buildTab(
    BuildContext context, {
    required List<PhotoWithWords> photos,
    required PreviewBuilder preview,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final shown = photos.take(3).toList();
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.primary,
        borderRadius: const BorderRadius.horizontal(left: Radius.circular(20)),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(-1, 2))],
      ),
      child: Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 10, left: 3),
        child: Column(
          children: [
            SizedBox(
              height: _countHeight,
              child: Center(
                child: Text(
                  '${photos.length}',
                  style: TextStyle(
                    color: scheme.onPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            SizedBox(
              width: _mini,
              height: _mini + (shown.length - 1) * (_mini - _overlap),
              child: Stack(
                children: [
                  for (final (i, photo) in shown.indexed)
                    Positioned(
                      top: i * (_mini - _overlap),
                      child: Container(
                        width: _mini,
                        height: _mini,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: scheme.onPrimary, width: 2),
                        ),
                        child: ClipOval(child: preview(photo, _mini)),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  bool get hidesTabWhileScrolling => true;

  @override
  double get halfOpenWidth => 128;

  @override
  Color panelColor(BuildContext context, {required bool fullOpen}) =>
      fullOpen ? const Color(0xFF1C1B22) : Theme.of(context).colorScheme.surface;

  @override
  double get handleBarHeight => 52;

  @override
  Widget buildGrip(BuildContext context) => Container(
        width: 6,
        height: 30,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(3),
        ),
      );

  @override
  Widget buildExpandIcon(BuildContext context) =>
      Icon(Icons.fullscreen, size: 24, color: Theme.of(context).colorScheme.primary);

  @override
  Widget buildCloseIcon(BuildContext context) =>
      Icon(Icons.chevron_right, size: 26, color: Theme.of(context).colorScheme.primary);

  @override
  Widget buildBackIcon(BuildContext context) =>
      const Icon(Icons.fullscreen_exit, size: 26, color: Colors.white70);

  @override
  double get smallPhotoExtent => 96;

  @override
  Widget buildSmallPhoto(BuildContext context, Widget preview, {required bool selected}) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 5,
            color: selected ? scheme.primary : Colors.transparent,
          ),
          const SizedBox(width: 5),
          Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(4), child: preview)),
          const SizedBox(width: 6),
        ],
      ),
    );
  }

  @override
  Widget buildLargeBrowser(
    BuildContext context, {
    required int count,
    required int initialIndex,
    required IndexedWidgetBuilder itemBuilder,
    required ValueChanged<int> onShown,
  }) =>
      _VerticalPhotoList(
        count: count,
        initialIndex: initialIndex,
        itemBuilder: itemBuilder,
        onShown: onShown,
      );

  @override
  Decoration rowHighlight(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return BoxDecoration(
      borderRadius: BorderRadius.circular(12),
      border: Border(left: BorderSide(color: primary, width: 5)),
      color: primary.withValues(alpha: 0.06),
    );
  }

  @override
  Widget buildPlaceholder(BuildContext context) => Semantics(
        label: 'Photo not available',
        child: ColoredBox(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: Center(
            child: Icon(Icons.broken_image_outlined,
                color: Theme.of(context).colorScheme.outline),
          ),
        ),
      );
}

/// Look B's full-open: the large photos one under another, each 85 % of the
/// view's height, scrolled as one list; the photo nearest the top is shown.
class _VerticalPhotoList extends StatefulWidget {
  const _VerticalPhotoList({
    required this.count,
    required this.initialIndex,
    required this.itemBuilder,
    required this.onShown,
  });

  final int count;
  final int initialIndex;
  final IndexedWidgetBuilder itemBuilder;
  final ValueChanged<int> onShown;

  @override
  State<_VerticalPhotoList> createState() => _VerticalPhotoListState();
}

class _VerticalPhotoListState extends State<_VerticalPhotoList> {
  ScrollController? _scroll;
  late int _shown = widget.initialIndex;

  @override
  void dispose() {
    _scroll?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, constraints) {
        final extent = constraints.maxHeight * 0.85;
        _scroll ??= ScrollController(initialScrollOffset: widget.initialIndex * extent);
        return NotificationListener<ScrollUpdateNotification>(
          onNotification: (n) {
            final i = (n.metrics.pixels / extent).round().clamp(0, widget.count - 1);
            if (i != _shown) {
              _shown = i;
              widget.onShown(i);
            }
            return false;
          },
          child: ListView.builder(
            controller: _scroll,
            itemExtent: extent,
            itemCount: widget.count,
            itemBuilder: (context, i) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: widget.itemBuilder(context, i),
            ),
          ),
        );
      });
}
