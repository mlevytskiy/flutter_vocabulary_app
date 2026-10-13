import 'package:flutter/material.dart';
import 'package:liquid_glass_renderer/liquid_glass_renderer.dart';

import '../photos_with_words.dart';
import 'photo_panel_look.dart';

/// Design variant A: a floating glass tab of stacked square previews with a
/// count badge, a floating glass column of rounded small photos, a dark
/// full-open that pages through the photos sideways, and a tinted row
/// highlight.
///
/// The glass is `liquid_glass_renderer`'s: it refracts and blurs the word
/// rows behind it on Impeller (iOS, most Android phones) and falls back to a
/// frosted blur with the same rim light where shaders are not available.
class LookA extends PhotoPanelLook {
  const LookA();

  static const _mini = 36.0;
  static const _gap = 6.0;
  static const _badge = 22.0;

  /// The glass floats this far from the screen's right edge.
  static const _edgeGap = 4.0;
  static const _tabRadius = 16.0;
  static const _panelRadius = 26.0;

  /// The half-open glass sits inside the panel's rect by this much, so it
  /// floats beside the rows like a sidebar on iOS.
  static const _panelInset = EdgeInsets.fromLTRB(4, 6, _edgeGap, 6);

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

  /// A soft shadow under a glass shape, so it lifts off a light background.
  static Widget _lifted(double radius, Widget glass) => DecoratedBox(
        decoration: ShapeDecoration(
          shape: RoundedSuperellipseBorder(
              borderRadius: BorderRadius.all(Radius.circular(radius))),
          shadows: const [
            BoxShadow(color: Color(0x1A3A1D6E), blurRadius: 18, offset: Offset(0, 6)),
          ],
        ),
        child: glass,
      );

  @override
  double get tabWidth => _mini + 2 * _gap + _edgeGap;

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
    return Padding(
      padding: const EdgeInsets.only(right: _edgeGap),
      child: _lifted(
        _tabRadius,
        LiquidGlass.withOwnLayer(
          settings: _tabGlass,
          shape: const LiquidRoundedSuperellipse(borderRadius: _tabRadius),
          child: Padding(
            padding: const EdgeInsets.all(_gap),
            child: Column(
              children: [
                for (final photo in photos.take(3))
                  Padding(
                    padding: const EdgeInsets.only(bottom: _gap),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
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

  /// Half-open is a floating glass column; on the way to full-open the
  /// glass fades out and the dark full-open surface fades in.
  @override
  Widget buildPanelSurface(BuildContext context,
          {required double fullness, required Widget child}) =>
      Stack(
        fit: StackFit.expand,
        children: [
          if (fullness < 1)
            Padding(
              padding: _panelInset * (1 - fullness),
              child: _lifted(
                _panelRadius,
                LiquidGlass.withOwnLayer(
                  settings: _panelGlass.copyWith(visibility: 1 - fullness),
                  shape: const LiquidRoundedSuperellipse(borderRadius: _panelRadius),
                  child: const SizedBox.expand(),
                ),
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
