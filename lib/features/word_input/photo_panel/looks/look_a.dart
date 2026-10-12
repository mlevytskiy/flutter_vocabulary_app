import 'package:flutter/material.dart';

import '../photos_with_words.dart';
import 'photo_panel_look.dart';

/// Design variant A: a card-like tab of stacked square previews with a count
/// badge, a surface-coloured column of rounded small photos, a dark full-open
/// that pages through the photos sideways, and a tinted row highlight.
class LookA extends PhotoPanelLook {
  const LookA();

  static const _mini = 36.0;
  static const _gap = 6.0;
  static const _badge = 22.0;

  @override
  double get tabWidth => _mini + 2 * _gap + 4;

  @override
  double tabHeight(int count) {
    final shown = count.clamp(1, 3);
    return _gap + shown * (_mini + _gap) + _badge + _gap;
  }

  @override
  Widget buildTab(
    BuildContext context, {
    required List<PhotoWithWords> photos,
    required PreviewBuilder preview,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerHigh,
      elevation: 4,
      borderRadius: const BorderRadius.horizontal(left: Radius.circular(14)),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(_gap + 4, _gap, _gap, _gap),
        child: Column(
          children: [
            for (final photo in photos.take(3))
              Padding(
                padding: const EdgeInsets.only(bottom: _gap),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: SizedBox.square(dimension: _mini, child: preview(photo, _mini)),
                ),
              ),
            Container(
              height: _badge,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: scheme.primary,
                borderRadius: BorderRadius.circular(_badge / 2),
              ),
              child: Text(
                '${photos.length}',
                style: TextStyle(
                  color: scheme.onPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  bool get hidesTabWhileScrolling => false;

  @override
  double get halfOpenWidth => 112;

  @override
  Color panelColor(BuildContext context, {required bool fullOpen}) => fullOpen
      ? Colors.black
      : Theme.of(context).colorScheme.surfaceContainerHigh;

  @override
  double get handleBarHeight => 48;

  @override
  Widget buildGrip(BuildContext context) => Container(
        width: 28,
        height: 4,
        decoration: BoxDecoration(
          color: Colors.grey.shade500,
          borderRadius: BorderRadius.circular(2),
        ),
      );

  @override
  Widget buildExpandIcon(BuildContext context) => const Icon(Icons.open_in_full, size: 20);

  @override
  Widget buildCloseIcon(BuildContext context) => const Icon(Icons.close, size: 20);

  @override
  Widget buildBackIcon(BuildContext context) =>
      const Icon(Icons.close_fullscreen, size: 22, color: Colors.white);

  @override
  double get smallPhotoExtent => 104;

  @override
  Widget buildSmallPhoto(BuildContext context, Widget preview, {required bool selected}) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? scheme.primary : Colors.transparent,
            width: 3,
          ),
        ),
        child: ClipRRect(borderRadius: BorderRadius.circular(7), child: preview),
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
      PageView.builder(
        controller: PageController(initialPage: initialIndex),
        itemCount: count,
        onPageChanged: onShown,
        itemBuilder: itemBuilder,
      );

  @override
  Decoration rowHighlight(BuildContext context) => BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      );

  @override
  Widget buildPlaceholder(BuildContext context) => Semantics(
        label: 'Photo not available',
        child: ColoredBox(
          color: Colors.grey.shade300,
          child: const Center(
            child: Icon(Icons.image_not_supported_outlined, color: Colors.black45),
          ),
        ),
      );
}
