import 'package:flutter/material.dart';

import '../photos_with_words.dart';

/// Builds one photo's preview at a logical [width] (a `PhotoPreview` with the
/// look's placeholder); the panel hands it to the look.
typedef PreviewBuilder = Widget Function(PhotoWithWords photo, double width);

/// The drawing part of a design variant (side-bar-for-main-screen ADR-0003).
///
/// It covers only what spec AC-19 lets a variant choose: how the tab, the
/// small and large photos, the controls, the placeholder and a highlighted
/// row look, how full-open browses the large photos, and whether the tab
/// hides while the word list scrolls. Everything else — gestures, stops,
/// selection, Back, Semantics labels and actions, the layout of the panel —
/// belongs to `PhotoPanel` and is the same for every look.
abstract class PhotoPanelLook {
  const PhotoPanelLook();

  /// Android honours at most 200 dp of gesture-excluded height per screen
  /// edge, so no tab may be taller (ADR-0002).
  static const double maxTabHeight = 200;

  // The photo tab (closed).

  double get tabWidth;

  /// The tab's height for [count] photos with words; read through
  /// [tabSizeFor], which checks it against [maxTabHeight].
  double tabHeight(int count);

  /// The tab's content: at most three mini previews (built with [preview])
  /// and the photo count. It fills the size [tabSizeFor] gives.
  Widget buildTab(
    BuildContext context, {
    required List<PhotoWithWords> photos,
    required PreviewBuilder preview,
  });

  /// Whether the tab fades out while the word list is scrolling (spec AC-19).
  bool get hidesTabWhileScrolling;

  // The panel (half-open and full-open).

  /// The half-open column's width.
  double get halfOpenWidth;

  /// The panel's surface colour behind the photos.
  Color panelColor(BuildContext context, {required bool fullOpen});

  /// The panel's surface with [child] (the panel's content) on it, at
  /// [fullness] from 0 (half-open) to 1 (full-open). It must give [child] a
  /// `Material` ancestor for the controls' ink. The default is a `Material`
  /// in [panelColor], blended by [fullness], with elevation 8.
  ///
  /// [halfOpenSize] is the half-open panel's size, exactly the same while
  /// the panel moves, at [halfOpenAt] in the surface's coordinates: on the
  /// way to half-open that spot rides on the panel's leading edge, on the way
  /// to full-open it stays where the half-open panel was. A surface that is
  /// costly to resize (glass) can draw there instead of across the whole,
  /// changing surface. (Two values, not a `Rect`: a rect's width comes back
  /// with rounding from its edges.)
  Widget buildPanelSurface(BuildContext context,
          {required double fullness,
          required Offset halfOpenAt,
          required Size halfOpenSize,
          required Widget child}) =>
      Material(
        color: Color.lerp(panelColor(context, fullOpen: false),
            panelColor(context, fullOpen: true), fullness),
        elevation: 8,
        child: child,
      );

  /// The height of the bar along the panel's top that holds the handle and
  /// the controls; a horizontal drag on it moves the panel (spec AC-10).
  double get handleBarHeight;

  /// The handle's grip, drawn in the middle of the bar — never at the left
  /// screen edge (spec AC-10).
  Widget buildGrip(BuildContext context);

  /// The visuals of the expand (half-open → full-open), close (half-open →
  /// closed) and back (full-open → half-open) controls. The panel makes them
  /// buttons and labels them.
  Widget buildExpandIcon(BuildContext context);
  Widget buildCloseIcon(BuildContext context);
  Widget buildBackIcon(BuildContext context);

  /// One small photo's height in the half-open column, spacing included.
  double get smallPhotoExtent;

  /// One small photo in the half-open column, framed by the look.
  Widget buildSmallPhoto(BuildContext context, Widget preview, {required bool selected});

  /// How full-open browses the large photos (a pager or a scrolling list,
  /// spec §8). It starts at [initialIndex], builds item `i` with
  /// [itemBuilder] and reports the shown photo through [onShown].
  Widget buildLargeBrowser(
    BuildContext context, {
    required int count,
    required int initialIndex,
    required IndexedWidgetBuilder itemBuilder,
    required ValueChanged<int> onShown,
  });

  /// The decoration of a highlighted word row (passed to `WordRowItem`).
  Decoration rowHighlight(BuildContext context);

  /// The "photo not available" placeholder (spec AC-09).
  Widget buildPlaceholder(BuildContext context);
}

/// The tab's size for [count] photos, checked against Android's 200 dp limit.
Size tabSizeFor(PhotoPanelLook look, int count) {
  final height = look.tabHeight(count);
  if (height > PhotoPanelLook.maxTabHeight) {
    throw AssertionError(
        'photo tab is ${height}dp tall; at most ${PhotoPanelLook.maxTabHeight}dp (ADR-0002)');
  }
  return Size(look.tabWidth, height);
}
