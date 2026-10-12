import 'package:flutter/material.dart';

import '../photos_with_words.dart';
import 'photo_panel_look.dart';

/// Design variant C: a dark, film-strip feel. The tab is a narrow dark strip
/// with one preview and a camera mark over the count, the half-open column
/// is dark with numbered photos, full-open swipes the large photos up and
/// down one at a time, and a highlighted row gets an outline. The tab stays
/// while the list scrolls.
class LookC extends PhotoPanelLook {
  const LookC();

  static const _strip = Color(0xE6222026);
  static const _mini = 32.0;

  @override
  double get tabWidth => 44;

  @override
  double tabHeight(int count) => count == 1 ? 72 : 96;

  @override
  Widget buildTab(
    BuildContext context, {
    required List<PhotoWithWords> photos,
    required PreviewBuilder preview,
  }) =>
      DecoratedBox(
        decoration: const BoxDecoration(
          color: _strip,
          borderRadius: BorderRadius.horizontal(left: Radius.circular(10)),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(7, 8, 5, 8),
          child: Column(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: SizedBox.square(dimension: _mini, child: preview(photos.first, _mini)),
              ),
              const Spacer(),
              if (photos.length > 1)
                const Icon(Icons.photo_library_outlined, size: 16, color: Colors.white70),
              Text(
                '${photos.length}',
                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      );

  @override
  bool get hidesTabWhileScrolling => false;

  @override
  double get halfOpenWidth => 120;

  @override
  Color panelColor(BuildContext context, {required bool fullOpen}) =>
      fullOpen ? Colors.black : _strip;

  @override
  double get handleBarHeight => 44;

  @override
  Widget buildGrip(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < 3; i++)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 2),
              width: 4,
              height: 4,
              decoration: const BoxDecoration(color: Colors.white54, shape: BoxShape.circle),
            ),
        ],
      );

  @override
  Widget buildExpandIcon(BuildContext context) =>
      const Icon(Icons.zoom_out_map, size: 20, color: Colors.white);

  @override
  Widget buildCloseIcon(BuildContext context) =>
      const Icon(Icons.close, size: 20, color: Colors.white);

  @override
  Widget buildBackIcon(BuildContext context) =>
      const Icon(Icons.zoom_in_map, size: 22, color: Colors.white);

  @override
  double get smallPhotoExtent => 92;

  @override
  Widget buildSmallPhoto(BuildContext context, Widget preview, {required bool selected}) {
    final accent = Theme.of(context).colorScheme.primaryContainer;
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 5, 8, 5),
      child: DecoratedBox(
        position: DecorationPosition.foreground,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: selected ? accent : Colors.white24, width: selected ? 3 : 1),
        ),
        child: ClipRRect(borderRadius: BorderRadius.circular(6), child: preview),
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
        scrollDirection: Axis.vertical,
        controller: PageController(initialPage: initialIndex),
        itemCount: count,
        onPageChanged: onShown,
        itemBuilder: itemBuilder,
      );

  @override
  Decoration rowHighlight(BuildContext context) => BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).colorScheme.primary, width: 2),
      );

  @override
  Widget buildPlaceholder(BuildContext context) => Semantics(
        label: 'Photo not available',
        child: const ColoredBox(
          color: Color(0xFF3A3840),
          child: Center(child: Icon(Icons.hide_image_outlined, color: Colors.white54)),
        ),
      );
}
