import 'dart:ui' show ImageFilter;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// The top bars' colour in the Classic theme: the main screen's word-row
/// background (`word_row_item.dart`), chosen by the owner 2026-10-16.
const classicTopBarColor = Color(0x57d9c1ff);

/// Classic's dark text purple: the Classic scheme's primary, the colour of
/// the top bar's Next button. It replaces Matcha's dark green in Classic's
/// row text and dark icons, and lilac greys replace Matcha's grey greens
/// (owner, 2026-10-18).
const classicDarkPurple = Color(0xFF68548E);

/// Every colour the screens used to hard-code, per theme (app-themes, owner
/// 2026-10-17). The defaults are the Classic values: the very constants the
/// screens had, except the text colours, which are Classic's purples (owner,
/// 2026-10-18; Matcha's greens before); [AppDecor.of] falls back
/// to it, so a widget built without an app theme (tests, previews) does too.
@immutable
class AppDecor extends ThemeExtension<AppDecor> {
  const AppDecor({
    this.topBar = classicTopBarColor,
    this.wordRow = const Color(0x57d9c1ff),
    this.wordRowBorder,
    this.wordRowRadius = 12,
    this.wordRowBlur = 0,
    this.rowText = classicDarkPurple,
    this.rowSubtext = const Color(0xFF7A6E92),
    this.rowIcon = const Color(0xFF8E24AA),
    this.rowHandle = const Color(0xFF7F77DD),
    this.rowClose = const Color(0xFFa883ca),
    this.popup = Colors.black87,
    this.onPopup = Colors.white,
    this.addAccent = const Color(0xFF2962FF),
    this.contextAccent = const Color(0xFF954EF3),
    this.fab = Colors.red,
    this.fabActive = const Color(0xFFD32F2F),
    this.onFab = Colors.white,
    this.fabAlt = const Color(0xff954ef3),
    this.onFabAlt = Colors.white,
    this.dialPhoto = Colors.green,
    this.dialSubtitles = const Color(0xFF7E57C2),
    this.dialQuizlet = Colors.blue,
    this.dialFolder = const Color(0xFFFFA000),
    this.onDial = Colors.white,
    this.barButton = Colors.white,
    this.onBarButton,
    this.paper = Colors.white,
    this.panel = const Color(0xFFF7F2FF),
    this.panelBorder = const Color(0x33954EF3),
    this.muted = const Color(0xFF9A90AA),
    this.subtle = const Color(0xFF7D7290),
    this.strongIcon = classicDarkPurple,
    this.placeholder = const Color(0xFFE0E0E0),
    this.onPlaceholder = Colors.black45,
    this.thumb = const Color(0xFFBDBDBD),
    this.bin = Colors.blueGrey,
    this.binHot = const Color(0xFFD32F2F),
    this.onBin = Colors.white,
    this.binFolder = const Color(0xFFFFB300),
    this.smallBin = Colors.blueGrey,
    this.onSmallBin = Colors.white,
    this.right = Colors.green,
    this.wrong = Colors.red,
    this.learnRight = const Color(0xFF2E9E5B),
    this.onLearnRight = Colors.white,
    this.learnWrong = const Color(0xFFE5604D),
    this.onLearnWrong = Colors.white,
    this.rateForgot = const Color(0xFFD84B4B),
    this.rateHard = const Color(0xFFEF8A2E),
    this.rateMedium = const Color(0xFF3F7FD9),
    this.rateEasy = const Color(0xFF2E9E5B),
    this.picked = Colors.blueGrey,
    this.pic50 = const Color(0xfff6effe),
    this.pic100 = const Color(0xffeee2fd),
    this.pic200 = const Color(0xffdcc4fb),
    this.pic500 = const Color(0xff954ef3),
    this.pic600 = const Color(0xff7c3ad6),
    this.picPaper = Colors.white,
    this.picOutline = false,
    this.glassTab = const Color(0x38FFFFFF),
    this.glassPanel = const Color(0x4DFFFFFF),
    this.glassEdge = const Color(0xFF9F86D8),
    this.glassShadow = const Color(0xFF3A1D6E),
    this.aiAccent = const Color(0xFF00838F),
    this.flowCard = Colors.white,
    this.flowCardBorder = const Color(0x33954EF3),
    this.flowCardShadow = const Color(0x293A1D6E),
    this.storyFrame = const Color(0xFF1E1530),
    this.onStoryFrame = Colors.white,
    this.backdrop,
    this.blobs = const [],
  });

  /// Every top bar (and `inversePrimary`).
  final Color topBar;

  /// A word row's fill, border, corner radius and the blur behind it (0: none).
  final Color wordRow;
  final BoxBorder? wordRowBorder;
  final double wordRowRadius;
  final double wordRowBlur;

  /// A one-line row's word and detail (the photo panel's rows).
  final Color rowText;
  final Color rowSubtext;

  /// A row's lightning buttons, three dots and speaker, drag handle, cross.
  final Color rowIcon;
  final Color rowHandle;
  final Color rowClose;

  /// The three dots' menu.
  final Color popup;
  final Color onPopup;

  /// The dashed "+ Add a word" button.
  final Color addAccent;

  /// Mixed half and half with [onBarButtonOf] for the Words screen's context
  /// pencil, "+add context" and the Context field's OK tick (Words: word
  /// context field, owner 2026-11-03). Classic's violet ([fabAlt]).
  final Color contextAccent;

  /// The plus button of a speed dial, and its open state.
  final Color fab;
  final Color fabActive;
  final Color onFab;

  /// The round button beside it (Settings).
  final Color fabAlt;
  final Color onFabAlt;

  /// The speed dials' small buttons.
  final Color dialPhoto;
  final Color dialSubtitles;
  final Color dialQuizlet;
  final Color dialFolder;
  final Color onDial;

  /// The buttons on a top bar (Rename, Next, Start); [onBarButton] null is
  /// the scheme's primary.
  final Color barButton;
  final Color? onBarButton;

  /// The white page of Notes; the Notes tag strip and pages, and their edge.
  final Color paper;
  final Color panel;
  final Color panelBorder;

  /// Empty-state text, secondary text, a dark close icon.
  final Color muted;
  final Color subtle;
  final Color strongIcon;

  /// A missing photo, its icon, and the back of a photo thumbnail.
  final Color placeholder;
  final Color onPlaceholder;
  final Color thumb;

  /// The recycle bin button, while something is held over it, its glyph; a
  /// folder's icon in the bin.
  final Color bin;
  final Color binHot;
  final Color onBin;
  final Color binFolder;

  /// Delete mode's small bin button beside each Collections item, and its
  /// glyph: the same blue-grey circle with a white bin in every theme, so it
  /// stands out on any background (owner, 2026-10-17).
  final Color smallBin;
  final Color onSmallBin;

  /// An exercise's right and wrong answers, and the one picked before.
  final Color right;
  final Color wrong;
  final Color picked;

  /// The Collections pictures' shades, lightest to darkest, their paper, and
  /// whether they are drawn as outlines only.
  final Color pic50;
  final Color pic100;
  final Color pic200;
  final Color pic500;
  final Color pic600;
  final Color picPaper;
  final bool picOutline;

  /// The photo tab's and panel's glass, its edge light and its shadow.
  final Color glassTab;
  final Color glassPanel;
  final Color glassEdge;
  final Color glassShadow;

  /// What AI will fill in: the sparkle and its words beside an empty field
  /// (collection-naming, owner 2026-10-18). A hue no tag tint, button or
  /// accent of the theme uses, so it reads as its own thing.
  final Color aiAccent;

  /// The learn page frame's verdict bar (learn-redesign, ADR-0011): the fill
  /// for "Right" / "Not quite" and the text and button colour on it.
  final Color learnRight;
  final Color onLearnRight;
  final Color learnWrong;
  final Color onLearnWrong;

  /// The self-check card's four rating buttons (learn-welcome AC-07,
  /// ADR-0006): I don't remember, Hard, Medium, Easy. Filled with these, the
  /// text black or white by their brightness; outlined in them in a theme
  /// with [picOutline].
  final Color rateForgot;
  final Color rateHard;
  final Color rateMedium;
  final Color rateEasy;

  /// The Learn flow's peek pager (learn-flow-cards, owner 2026-11-01): each
  /// page's card fill, its border and its shadow (also the lift of a card
  /// turning over).
  final Color flowCard;
  final Color flowCardBorder;
  final Color flowCardShadow;

  /// The dark frame behind a story picture (the story card and its full
  /// screen zoom) and the icons on it.
  final Color storyFrame;
  final Color onStoryFrame;

  /// Painted behind the main screen's list: a gradient and soft colour blobs.
  final Gradient? backdrop;
  final List<Color> blobs;

  static const classic = AppDecor();

  static AppDecor of(BuildContext context) =>
      Theme.of(context).extension<AppDecor>() ?? classic;

  Color onBarButtonOf(BuildContext context) =>
      onBarButton ?? Theme.of(context).colorScheme.primary;

  @override
  AppDecor copyWith() => this;

  /// Themes switch at the halfway point; [MaterialApp] still animates the
  /// colour scheme around it.
  @override
  AppDecor lerp(AppDecor? other, double t) =>
      other == null || t < 0.5 ? this : other;
}

/// Paints [AppDecor.backdrop] and its blobs behind [child]; nothing in a theme
/// without one. The tree is the same either way, so switching themes keeps
/// the state below.
class AppBackdrop extends StatelessWidget {
  const AppBackdrop({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => CustomPaint(
        painter: _BackdropPainter(AppDecor.of(context)),
        child: child,
      );
}

class _BackdropPainter extends CustomPainter {
  _BackdropPainter(this.decor);

  final AppDecor decor;

  // Where the blobs sit, as fractions of the size, and their radius as a
  // fraction of the shorter side.
  static const _spots = [
    (0.12, 0.10, 0.75),
    (0.95, 0.38, 0.70),
    (0.20, 0.78, 0.80),
    (0.85, 0.95, 0.60),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    if (decor.backdrop != null) {
      canvas.drawRect(
          rect, Paint()..shader = decor.backdrop!.createShader(rect));
    }
    final side = size.shortestSide;
    for (var i = 0; i < decor.blobs.length && i < _spots.length; i++) {
      final (x, y, r) = _spots[i];
      final center = Offset(size.width * x, size.height * y);
      final radius = side * r;
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..shader = RadialGradient(
            colors: [decor.blobs[i], decor.blobs[i].withValues(alpha: 0)],
          ).createShader(Rect.fromCircle(center: center, radius: radius)),
      );
    }
  }

  @override
  bool shouldRepaint(_BackdropPainter old) => old.decor != decor;
}

/// A word row's surface: the theme's fill, border and radius, with a frosted
/// blur behind it when the theme has one. The tree does not depend on the
/// theme, so a switch keeps the row's state.
class DecorSurface extends StatelessWidget {
  const DecorSurface({
    super.key,
    required this.padding,
    this.margin = EdgeInsets.zero,
    this.foregroundDecoration,
    required this.child,
  });

  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final Decoration? foregroundDecoration;
  final Widget child;

  /// Overrides whether every surface blurs live (off Android); tests only.
  @visibleForTesting
  static bool? debugBlurEverywhere;

  /// Whether a surface blurs what is under it wherever it is. Off Android,
  /// yes. On Android only under a [LiveBlur]: a backdrop blur is drawn again
  /// on every frame anything moves over the list (the side menu, the + menu,
  /// a sheet), one full-screen pass per frame, which the phones the owner
  /// tried could not keep up with (2026-10-18). Under a row at rest there is
  /// only the theme's smooth backdrop, and a blur of a smooth gradient is
  /// that gradient, so skipping it there changes nothing seen. Where other
  /// rows can pass under a surface -- a row dragged over the list -- the
  /// [LiveBlur] marker keeps the frosted glass.
  static bool get blurEverywhere =>
      debugBlurEverywhere ?? defaultTargetPlatform != TargetPlatform.android;

  @override
  Widget build(BuildContext context) {
    final decor = AppDecor.of(context);
    final radius = BorderRadius.circular(decor.wordRowRadius);
    final blur = decor.wordRowBlur;
    final live = blur > 0 && (blurEverywhere || LiveBlur.of(context));
    // A non-uniform border (a ruled line) cannot take rounded corners.
    final uniform = decor.wordRowBorder is! Border ||
        (decor.wordRowBorder! as Border).isUniform;
    return Padding(
      padding: margin,
      child: ClipRRect(
        borderRadius: radius,
        clipBehavior: live ? Clip.antiAlias : Clip.none,
        child: BackdropFilter(
          enabled: live,
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          // Rows under one BackdropGroup share a single backdrop read: one
          // per row made the Android drawer lag in Aurora (owner, 2026-10-18).
          // While the drawer is on screen the main screen's body is one
          // picture, so the blur is not drawn again per frame (StillBody).
          backdropGroupKey: BackdropGroup.of(context)?.backdropKey,
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              color: decor.wordRow,
              border: decor.wordRowBorder,
              borderRadius: uniform ? radius : null,
            ),
            foregroundDecoration: foregroundDecoration,
            child: child,
          ),
        ),
      ),
    );
  }
}

/// Marks a subtree whose [DecorSurface]s blur what is under them live even
/// on Android: see [DecorSurface.blurEverywhere]. The main screen puts it on
/// the row being dragged over the others.
class LiveBlur extends InheritedWidget {
  const LiveBlur({super.key, required super.child});

  static bool of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<LiveBlur>() != null;

  @override
  bool updateShouldNotify(LiveBlur old) => false;
}
