import 'package:flutter/material.dart';
import 'package:liquid_glass_renderer/liquid_glass_renderer.dart';

import '../photos_with_words.dart';
import 'edge_glass.dart';
import 'photo_panel_look.dart';

/// Design variant A: a glass tab of stacked square previews with a count
/// badge and a glass column of rounded small photos, both stuck to the screen
/// edge with concave flares ([EdgeGlass]), a dark full-open that pages
/// through the photos sideways, and a tinted row highlight.
///
/// The glass is `liquid_glass_renderer`'s: it refracts and blurs the word
/// rows behind it on Impeller (iOS, most Android phones) and falls back to a
/// frosted blur with the same outline where shaders are not available.
class LookA extends PhotoPanelLook {
  const LookA();

  static const _mini = 36.0;
  static const _gap = 6.0;
  static const _badge = 22.0;

  /// The tab's content keeps this far from its sides.
  static const _tabPad = 8.0;
  static const _tabRadius = 16.0;
  static const _tabFlare = 14.0;
  static const _panelRadius = 26.0;
  static const _panelFlare = 20.0;

  static const _tabGlass = LiquidGlassSettings(
    thickness: 16,
    blur: 3,
    glassColor: Color(0x38FFFFFF),
    lightIntensity: .7,
    saturation: 1.6,
    refractiveIndex: 1.25,
    chromaticAberration: .02,
  );

  static const _panelGlass = LiquidGlassSettings(
    thickness: 26,
    blur: 9,
    glassColor: Color(0x4DFFFFFF),
    lightIntensity: .65,
    ambientStrength: .15,
    saturation: 1.6,
    refractiveIndex: 1.2,
    chromaticAberration: .015,
  );

  @override
  double get tabWidth => _mini + 2 * _tabPad;

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
    return EdgeGlass(
      settings: _tabGlass,
      radius: _tabRadius,
      flare: _tabFlare,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(_tabPad, _gap, _tabPad, _gap),
        child: Column(
          children: [
            for (final photo in photos.take(3))
              Padding(
                padding: const EdgeInsets.only(bottom: _gap),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: SizedBox.square(
                      dimension: _mini, child: preview(photo, _mini)),
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

  /// Half-open is a glass column stuck to the screen edge, its flares
  /// running up over the top bar; on the way to full-open the dark full-open
  /// surface fades in over it.
  ///
  /// The glass is always drawn at [halfOpenSize], at [halfOpenAt], so it
  /// slides in and out rather than growing, and it is covered rather than
  /// faded: the package rebuilds the glass's shape texture whenever its size
  /// or thickness changes, which costs a frame's worth of GPU time on Android.
  @override
  Widget buildPanelSurface(BuildContext context,
          {required double fullness,
          required Offset halfOpenAt,
          required Size halfOpenSize,
          required Widget child}) =>
      Stack(
        fit: StackFit.expand,
        clipBehavior: Clip.none,
        children: [
          if (fullness < 1)
            Positioned(
              left: halfOpenAt.dx,
              top: halfOpenAt.dy,
              width: halfOpenSize.width,
              height: halfOpenSize.height,
              child: const EdgeGlass(
                settings: _panelGlass,
                radius: _panelRadius,
                flare: _panelFlare,
              ),
            ),
          if (fullness > 0)
            Opacity(
              opacity: fullness,
              child: ColoredBox(color: panelColor(context, fullOpen: true)),
            ),
          Material(type: MaterialType.transparency, child: child),
        ],
      );

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
  Widget buildExpandIcon(BuildContext context) =>
      const Icon(Icons.open_in_full, size: 20);

  @override
  Widget buildCloseIcon(BuildContext context) =>
      const Icon(Icons.close, size: 20);

  @override
  Widget buildBackIcon(BuildContext context) =>
      const Icon(Icons.close_fullscreen, size: 22, color: Colors.white);

  @override
  double get smallPhotoExtent => 104;

  @override
  Widget buildSmallPhoto(BuildContext context, Widget preview,
      {required bool selected}) {
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
        child:
            ClipRRect(borderRadius: BorderRadius.circular(7), child: preview),
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
            child:
                Icon(Icons.image_not_supported_outlined, color: Colors.black45),
          ),
        ),
      );
}
