import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flutter/foundation.dart';

import '../../../core/providers.dart';
import '../../../core/services/system_gesture_exclusion.dart';
import 'looks/look_a.dart';
import 'looks/photo_panel_look.dart';
import 'photo_panel_controller.dart';
import 'photo_panel_stops.dart';
import 'photo_preview.dart';
import 'photos_with_words.dart';
import 'source_hero.dart';
import 'source_tile.dart';

/// The photo tab and photo panel over the main screen's words page
/// (side-bar-for-main-screen, ADR-0001).
///
/// Mounted by the main screen as a `Positioned.fill` child over its word list;
/// that child only marks the words page's place. The tab and the panel are
/// drawn through an [OverlayPortal] above the route, so a touch that starts on
/// them is hit-tested first and never reaches the rows or the pager (spec
/// AC-13, AC-14). With no source with words nothing is drawn (spec AC-02).
///
/// The tab and the half-open column list the sources with words, photos and
/// Quizlet sets mixed; full-open shows the photos only, and with no photo it
/// cannot be reached (side-panel-sources, spec AC-21).
class PhotoPanel extends ConsumerStatefulWidget {
  const PhotoPanel({
    super.key,
    required this.controller,
    this.busy = false,
    this.hidden = false,
    this.bottomReserve = 0,
    this.scrollController,
    this.onSelected,
    this.onOpenNotes,
    this.notesPage,
    @visibleForTesting this.look,
  });

  static const tabKey = Key('photo-panel-tab');
  static const panelKey = Key('photo-panel');
  static const handleKey = Key('photo-panel-handle');
  static const expandKey = Key('photo-panel-expand');
  static const closeKey = Key('photo-panel-close');
  static const backKey = Key('photo-panel-back');
  static const growingPhotoKey = Key('photo-panel-growing-photo');
  static const notesRevealKey = Key('photo-panel-notes-reveal');
  static const largeBrowserKey = Key('photo-panel-large-browser');
  static Key smallPhotoKey(String id) => ValueKey('photo-panel-small-$id');
  static Key largePhotoKey(String id) => ValueKey('photo-panel-large-$id');

  final PhotoPanelController controller;

  /// The screen is analysing a photo: the tab ignores touches (spec AC-17).
  final bool busy;

  /// Nothing is drawn, e.g. while the drawer is open (ADR-0001).
  final bool hidden;

  /// Height kept free at the bottom of the words page for the floating
  /// buttons and a SnackBar; the tab never goes lower (spec AC-01).
  final double bottomReserve;

  /// The word list's controller; its scrolling hides the tab for a look that
  /// asks for it (spec AC-19).
  final ScrollController? scrollController;

  /// Called after the selected photo changes, with the new one or null; the
  /// screen highlights its rows and jumps to the first (spec AC-04, AC-05).
  final ValueChanged<String?>? onSelected;

  /// Opens the Notes page with the selected source id, and completes when
  /// it is closed. With it, the expand control opens Notes instead of
  /// full-open, for any source, and the small pictures fly to their Notes
  /// pages as heroes; the panel stays half-open under it (owner, 2026-10-15).
  final Future<void> Function(String? selectedId)? onOpenNotes;

  /// The Notes page as [onOpenNotes] will show it, for the selected source.
  /// With it, a drag past half-open reveals this page over the panel as it
  /// widens, instead of the large photos, and settling at full-open opens
  /// Notes from there with nothing changing on screen (owner, 2026-10-15).
  final Widget Function(String? selectedId)? notesPage;

  /// Overrides look A; tests only.
  final PhotoPanelLook? look;

  @override
  ConsumerState<PhotoPanel> createState() => _PhotoPanelState();
}

class _PhotoPanelState extends ConsumerState<PhotoPanel>
    with SingleTickerProviderStateMixin {
  /// How long a whole slide takes between closed and half-open, and between
  /// half-open and full-open; a part of one takes its share. Half-open is
  /// settled within 300 ms of a tap (spec NFR), word rows' morph included.
  static const _halfOpenDuration = Duration(milliseconds: 280);
  static const _fullOpenDuration = Duration(milliseconds: 250);

  final _portal = OverlayPortalController();

  /// The one openness value: 0 closed, 0.5 half-open, 1 full-open (ADR-0001).
  late final AnimationController _openness;
  double? _animatingTo;

  /// A horizontal drag of the panel (from the tab, the half-open panel or
  /// the handle) is in progress, and the stop it started from.
  bool _panelDragging = false;
  PanelStop _dragStartStop = PanelStop.closed;

  /// The tab's top while it is dragged up or down, unclamped.
  double? _dragTop;

  /// How the current drag on the tab was read: up/down moves the tab, left
  /// opens the panel; one drag never does both (spec AC-14).
  _TabDrag _tabDrag = _TabDrag.none;
  double _tabStartTop = 0;

  /// Where the finger went down on the tab, and how far the current drag has
  /// moved the panel so far; drags follow the finger from there, so the
  /// touch slop is not lost.
  Offset _tabDown = Offset.zero;
  double _tabDragDx = 0;

  ScrollPosition? _watchedPosition;
  bool _listScrolling = false;

  /// The half-open column of small photos.
  final _column = ScrollController();

  /// The photos read and decoded at the half-open size (and Notes' size)
  /// while the panel is closed, so half-open and Notes draw them at once
  /// (owner, 2026-10-15).
  PhotoPreloader get _preloader => ref.read(photoPreloaderProvider);
  bool _preloadScheduled = false;

  /// The tab's and the panel's frosted glass (Android) share one read of
  /// the screen behind them per frame; one key for the panel's life.
  final _backdropKey = BackdropKey();

  /// Full-open: the large photo shown now (null outside full-open) and each
  /// large photo's zoom, kept while full-open lasts.
  int? _shown;
  final _zooms = <String, TransformationController>{};

  /// The last layout: the words page and the whole overlay, in overlay
  /// coordinates. Set while the overlay child is laid out.
  Rect _page = Rect.zero;
  Size _overlay = Size.zero;

  /// The rectangles last sent to Android's gesture exclusion, and the ones
  /// this frame wants (ADR-0002).
  late final SystemGestureExclusion _exclusion;
  List<Rect> _sentRects = const [];
  List<Rect> _wantedRects = const [];
  double _devicePixelRatio = 1;
  bool _sendScheduled = false;

  PhotoPanelLook get _look => widget.look ?? const LookA();

  /// The session has a photo with words, so full-open can be reached (spec
  /// AC-21). Set in build.
  bool _hasPhotos = true;

  /// The highest stop the panel can reach now.
  PanelStop _limit(PanelStop stop) =>
      !_hasPhotos && stop == PanelStop.fullOpen ? PanelStop.halfOpen : stop;

  @override
  void initState() {
    super.initState();
    _openness = AnimationController(
        vsync: this, value: widget.controller.stop.openness);
    widget.controller.attachOpenness(_openness);
    _exclusion = ref.read(systemGestureExclusionProvider);
    _portal.show();
    widget.controller.addListener(_onControllerChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) => _watchScrolling());
  }

  @override
  void didUpdateWidget(PhotoPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onControllerChanged);
      oldWidget.controller.attachOpenness(null);
      widget.controller.addListener(_onControllerChanged);
      widget.controller.attachOpenness(_openness);
      _onControllerChanged();
    }
    if (oldWidget.scrollController != widget.scrollController) {
      _watchScrolling();
    }
    // The word list may have been rebuilt with a new position, e.g. after
    // the pager left the words page and came back.
    WidgetsBinding.instance.addPostFrameCallback((_) => _watchScrolling());
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    widget.controller.attachOpenness(null);
    _route?.secondaryAnimation?.removeStatusListener(_onRouteCovered);
    if (_sentRects.isNotEmpty) _exclusion.clear();
    _watchedPosition?.isScrollingNotifier.removeListener(_onScrolling);
    _openness.dispose();
    _column.dispose();
    _disposeZooms();
    super.dispose();
  }

  /// Follows the word list's scrolling (the position appears after the list's
  /// first layout and changes when the list is rebuilt).
  void _watchScrolling() {
    if (!mounted) return;
    final c = widget.scrollController;
    final position = c != null && c.hasClients ? c.position : null;
    if (identical(position, _watchedPosition)) return;
    _watchedPosition?.isScrollingNotifier.removeListener(_onScrolling);
    _watchedPosition = position;
    position?.isScrollingNotifier.addListener(_onScrolling);
  }

  void _onScrolling() {
    final scrolling = _watchedPosition?.isScrollingNotifier.value ?? false;
    if (scrolling != _listScrolling && mounted) {
      setState(() => _listScrolling = scrolling);
    }
  }

  // The stop and the openness.

  /// The controller's stop changed (a settle, Back, a close from the screen):
  /// animate to it, unless a drag owns the openness.
  void _onControllerChanged() {
    if (!mounted) return;
    setState(() {}); // the selection may have changed too
    if (_panelDragging || _toNotes) return;
    _animateTo(widget.controller.stop.openness);
  }

  void _animateTo(double target) {
    if (_animatingTo == target && _openness.isAnimating) return;
    if (_openness.value == target && !_openness.isAnimating) return;
    if (_openness.value == 0 && target > 0) _unfocus();
    _animatingTo = target;
    _openness
        .animateTo(target,
            duration: _slideDuration(_openness.value, target),
            curve: Curves.easeOutCubic)
        .whenCompleteOrCancel(() => _animatingTo = null);
  }

  /// The slide from openness [from] to [to]: each half of the way takes its
  /// share of that half's duration, so the rest of a drag is not slow.
  static Duration _slideDuration(double from, double to) {
    double part(double lo, double hi) =>
        (from.clamp(lo, hi) - to.clamp(lo, hi)).abs() / 0.5;
    final us = part(0, 0.5) * _halfOpenDuration.inMicroseconds +
        part(0.5, 1) * _fullOpenDuration.inMicroseconds;
    return Duration(microseconds: math.max(us.round(), 100000));
  }

  /// Opening closes the keyboard; the field keeps its text (spec AC-03).
  void _unfocus() => FocusManager.instance.primaryFocus?.unfocus();

  void _open(PanelStop stop) {
    if (widget.busy) return;
    widget.controller.setStop(_limit(stop));
  }

  /// The Notes page is on top: the panel stays half-open under it, so its
  /// small pictures are there for the heroes to fly back to.
  bool _inNotes = false;

  /// The expand control: Notes when the screen gives it, otherwise full-open.
  Future<void> _expand() async {
    final openNotes = widget.onOpenNotes;
    if (openNotes == null) return _open(PanelStop.fullOpen);
    if (widget.busy || _inNotes) return;
    _inNotes = true;
    try {
      await openNotes(widget.controller.selectedId);
    } finally {
      _inNotes = false;
      _backToHalf();
    }
  }

  /// The panel is widening into the Notes page after a drag, or is drawn as
  /// it under the Notes page until that page covers the screen.
  bool _toNotes = false;

  bool get _revealsNotes =>
      widget.onOpenNotes != null && widget.notesPage != null;

  /// A drag settled at full-open with Notes: the panel finishes widening into
  /// the Notes page, then the page is pushed over it. Once it covers the
  /// screen the panel goes back to half-open beneath ([_onRouteCovered]).
  void _widenIntoNotes() {
    _toNotes = true;
    if (widget.controller.stop != PanelStop.halfOpen) {
      widget.controller.setStop(PanelStop.halfOpen);
    }
    _animatingTo = 1;
    _openness
        .animateTo(1,
            duration: _slideDuration(_openness.value, 1),
            curve: Curves.easeOutCubic)
        .whenCompleteOrCancel(() {
      _animatingTo = null;
      if (!mounted || !_toNotes) return;
      if (widget.busy || _inNotes) {
        _backToHalf(animate: true);
      } else {
        _expand();
      }
    });
  }

  /// Leaves the Notes look: back at half-open, at once when hidden under the
  /// Notes page, or sliding back when Notes did not open.
  void _backToHalf({bool animate = false}) {
    if (!_toNotes || !mounted) return;
    _toNotes = false;
    final half = PanelStop.halfOpen.openness;
    if (animate) {
      _animateTo(half);
    } else {
      _openness.value = half;
    }
  }

  /// The main screen's route, whose covering by Notes is watched.
  ModalRoute<Object?>? _route;

  void _onRouteCovered(AnimationStatus status) {
    if (status == AnimationStatus.completed) _backToHalf();
  }

  double get _halfWidth => _look.halfOpenWidth;
  double get _fullWidth => _overlay.width;

  /// The panel's width at openness [t], and back.
  double _widthOf(double t) => t <= 0.5
      ? _halfWidth * t / 0.5
      : _halfWidth + (_fullWidth - _halfWidth) * (t - 0.5) / 0.5;

  double _opennessOf(double width) {
    final w = width.clamp(0.0, _fullWidth);
    return w <= _halfWidth
        ? 0.5 * w / _halfWidth
        : 0.5 + 0.5 * (w - _halfWidth) / (_fullWidth - _halfWidth);
  }

  /// Pixels of drag per unit of openness at [t].
  double _pixelsPerOpenness(double t) =>
      (t < 0.5 ? _halfWidth : _fullWidth - _halfWidth) / 0.5;

  void _beginPanelDrag() {
    _panelDragging = true;
    _dragStartStop = widget.controller.stop;
    _openness.stop();
    if (_dragStartStop == PanelStop.closed) _unfocus();
  }

  /// A drag can widen the panel past half-open: towards full-open, or towards
  /// Notes when the screen opens Notes (for any source, not only photos).
  bool get _dragsPastHalf => _hasPhotos || widget.onOpenNotes != null;

  void _panelDragBy(double dx) {
    if (!_panelDragging) return;
    final t = _opennessOf(_widthOf(_openness.value) - dx);
    _openness.value =
        _dragsPastHalf ? t : math.min(t, PanelStop.halfOpen.openness);
  }

  /// Settles at a stop by the rule (spec AC-08). With Notes, a drag that
  /// would settle at full-open opens Notes instead, and the panel goes back
  /// to half-open under it, where the picture flies from (owner, 2026-10-15).
  void _endPanelDrag(double velocityX) {
    if (!_panelDragging) return;
    _panelDragging = false;
    final velocity = -velocityX / _pixelsPerOpenness(_openness.value);
    var stop = settle(_dragStartStop, _openness.value, velocity);
    if (stop == PanelStop.fullOpen && widget.onOpenNotes != null) {
      if (_revealsNotes) return _widenIntoNotes();
      stop = PanelStop.halfOpen;
      _expand();
    }
    stop = _limit(stop);
    _animateTo(stop.openness);
    widget.controller.setStop(stop);
    // The same stop again does not notify; settle back to it anyway.
    _animateTo(stop.openness);
  }

  // The tab's height on the words page.

  double _tabTop(Size page, Size tab) => PhotoTabTopNotifier.clamp(
        _dragTop ?? ref.watch(photoTabTopProvider),
        min: 0,
        max: page.height - widget.bottomReserve - tab.height,
      );

  void _onTabPanDown(DragDownDetails d) => _tabDown = d.globalPosition;

  /// The first movement past the touch slop decides the direction.
  void _onTabPanStart(double currentTop) {
    _tabDrag = _TabDrag.undecided;
    _tabStartTop = currentTop;
    _tabDragDx = 0;
  }

  void _onTabPanUpdate(DragUpdateDetails d) {
    final moved = d.globalPosition - _tabDown;
    if (_tabDrag == _TabDrag.undecided) {
      if (moved.dy.abs() > moved.dx.abs()) {
        _tabDrag = _TabDrag.move;
      } else if (moved.dx < 0) {
        _tabDrag = _TabDrag.open;
        _beginPanelDrag();
      } else {
        _tabDrag = _TabDrag.none;
      }
    }
    switch (_tabDrag) {
      case _TabDrag.move:
        setState(() => _dragTop = _tabStartTop + moved.dy);
      case _TabDrag.open:
        _panelDragBy(moved.dx - _tabDragDx);
        _tabDragDx = moved.dx;
      case _TabDrag.none:
      case _TabDrag.undecided:
        break;
    }
  }

  void _onTabPanEnd(Size page, Size tab, double velocityX) {
    switch (_tabDrag) {
      case _TabDrag.move:
        final top = PhotoTabTopNotifier.clamp(
          _dragTop!,
          min: 0,
          max: page.height - widget.bottomReserve - tab.height,
        );
        ref.read(photoTabTopProvider.notifier).set(top);
        setState(() => _dragTop = null);
      case _TabDrag.open:
        _endPanelDrag(velocityX);
      case _TabDrag.none:
      case _TabDrag.undecided:
        break;
    }
    _tabDrag = _TabDrag.none;
  }

  // Selection.

  void _select(String id) {
    widget.controller.select(id);
    widget.onSelected?.call(widget.controller.selectedId);
  }

  /// Full-open starts at the selected photo, or at the first photo when no
  /// photo (or a set) is selected (spec AC-07b, AC-21).
  int _startIndex(List<PhotoWithWords> photos) {
    final i =
        photos.indexWhere((p) => p.source.id == widget.controller.selectedId);
    return i < 0 ? 0 : i;
  }

  void _disposeZooms() {
    for (final z in _zooms.values) {
      z.dispose();
    }
    _zooms.clear();
  }

  // The Android Back-gesture exclusion (ADR-0002).

  /// What Android should leave to the app now: the tab while closed, the
  /// handle while half-open, nothing in full-open or with no tab.
  List<Rect> _exclusionFor(List<SourceWithWords> photos) {
    if (photos.isEmpty || widget.hidden || !_routeIsCurrent) return const [];
    final look = _look;
    switch (widget.controller.stop) {
      case PanelStop.closed:
        if (look.hidesTabWhileScrolling && _listScrolling) return const [];
        final tab = tabSizeFor(look, photos.length);
        final top = _page.top + _tabTop(_page.size, tab);
        return [
          Rect.fromLTWH(_page.right - tab.width, top, tab.width, tab.height)
        ];
      case PanelStop.halfOpen:
        final half = _panelRect(0.5);
        return [
          Rect.fromLTWH(half.left, half.top, half.width, look.handleBarHeight)
        ];
      case PanelStop.fullOpen:
        return const [];
    }
  }

  /// Sends [rects] after this frame if they differ from what Android has.
  void _want(List<Rect> rects) {
    _wantedRects = rects;
    if (_sendScheduled) return;
    _sendScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _sendScheduled = false;
      if (!mounted || listEquals(_wantedRects, _sentRects)) return;
      _sentRects = _wantedRects;
      debugPrint('VOCAB: photo panel exclusion $_sentRects');
      if (_sentRects.isEmpty) {
        _exclusion.clear();
      } else {
        _exclusion.setRects(_sentRects, devicePixelRatio: _devicePixelRatio);
      }
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  // Drawing.

  /// A photo's preview, or a non-photo source's mini tile (the tab's
  /// previews, spec AC-21).
  Widget _preview(SourceWithWords photo, double width,
          {BoxFit fit = BoxFit.cover}) =>
      !photo.isPhoto
          ? SourceTile(source: photo.source, mini: true)
          : PhotoPreview(
        key: ValueKey('photo-panel-preview-${photo.source.id}-$width'),
        source: photo.source,
        width: width,
        fit: fit,
        placeholder: _look.buildPlaceholder,
        preloader: _preloader,
      );

  /// After this frame, starts reading and decoding the sources the panel
  /// does not have yet, so the main screen's first frame never waits.
  void _schedulePreload(List<SourceWithWords> sources) {
    if (_preloadScheduled) return;
    _preloadScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _preloadScheduled = false;
      if (!mounted) return;
      _preloader.preload(
          context, ref.read(sourcePhotoStoreProvider), [
        for (final s in sources) s.source
      ], [
        _look.halfOpenWidth,
        if (widget.onOpenNotes != null)
          notesPictureWidth(MediaQuery.sizeOf(context).width),
      ]);
    });
  }

  Rect _panelRect(double t) {
    final half = Rect.fromLTRB(
        _page.right - _halfWidth, _page.top, _page.right, _page.bottom);
    if (t <= 0.5) {
      return Rect.fromLTRB(
          _page.right - _widthOf(t), _page.top, _page.right, _page.bottom);
    }
    return Rect.lerp(half, Offset.zero & _overlay, (t - 0.5) / 0.5)!;
  }

  Widget _control(BuildContext context,
          {required Key key,
          required String label,
          required Widget icon,
          required VoidCallback onTap}) =>
      Semantics(
        button: true,
        label: label,
        excludeSemantics: true,
        onTap: onTap,
        child: InkResponse(
          key: key,
          onTap: onTap,
          child: SizedBox.square(dimension: 48, child: Center(child: icon)),
        ),
      );

  /// A small picture flies to its Notes page when the panel opens Notes.
  Widget _heroed(String id, Widget picture) => widget.onOpenNotes == null
      ? picture
      : SourceHero(id: id, small: true, child: picture);

  /// The half-open column: the handle bar with close and expand (expand only
  /// with a photo to show large), then the small photos and set tiles, oldest
  /// first (spec AC-03, AC-21).
  Widget _halfContent(BuildContext context, List<SourceWithWords> photos) {
    final look = _look;
    final selected = widget.controller.selectedId;
    final photoWidth = look.halfOpenWidth;
    return SizedBox(
      width: look.halfOpenWidth,
      child: Column(
        children: [
          SizedBox(
            key: PhotoPanel.handleKey,
            height: look.handleBarHeight,
            child: Row(
              children: [
                _control(context,
                    key: PhotoPanel.closeKey,
                    label: 'Close photos',
                    icon: look.buildCloseIcon(context),
                    onTap: widget.controller.close),
                // Transparent, so a drag between the controls moves the panel
                // even where the look draws no grip (spec AC-10).
                Expanded(
                    child: ColoredBox(
                        color: Colors.transparent,
                        child: Center(child: look.buildGrip(context)))),
                if (widget.onOpenNotes != null)
                  _control(context,
                      key: PhotoPanel.expandKey,
                      label: 'Open notes',
                      icon: look.buildExpandIcon(context),
                      onTap: _expand)
                else if (_hasPhotos)
                  _control(context,
                      key: PhotoPanel.expandKey,
                      label: 'Show photos large',
                      icon: look.buildExpandIcon(context),
                      onTap: _expand)
                else
                  const SizedBox(width: 48),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              controller: _column,
              padding: EdgeInsets.zero,
              itemExtent: look.smallPhotoExtent,
              itemCount: photos.length,
              itemBuilder: (context, i) {
                final item = photos[i];
                final id = item.source.id;
                // A selectable button for a screen reader (spec AC-18); a
                // photo is counted among the photos, a set named (AC-21).
                return Semantics(
                  container: true,
                  button: true,
                  selected: id == selected,
                  label: item.isPhoto
                      ? 'Photo ${_photoCount(photos, i) + 1} of ${_photoCount(photos, photos.length)}'
                      : SourceTile.semanticsLabel(item.source),
                  excludeSemantics: true,
                  onTap: () => _select(id),
                  child: GestureDetector(
                    key: PhotoPanel.smallPhotoKey(id),
                    behavior: HitTestBehavior.opaque,
                    onTap: () => _select(id),
                    child: look.buildSmallPhoto(
                      context,
                      _heroed(
                          id,
                          item.isPhoto
                              ? _preview(item, photoWidth)
                              : SourceTile(
                                  source: item.source,
                                  wordCount: item.rows.length)),
                      selected: id == selected,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  /// Full-open: the handle bar with the control back to half-open, then the
  /// large photos browsed the look's way (spec AC-07b).
  Widget _fullContent(BuildContext context, List<PhotoWithWords> photos) {
    final look = _look;
    final shown = _shown ??= _startIndex(photos);
    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          GestureDetector(
            key: PhotoPanel.handleKey,
            behavior: HitTestBehavior.opaque,
            onHorizontalDragStart: (_) => _beginPanelDrag(),
            onHorizontalDragUpdate: (d) => _panelDragBy(d.delta.dx),
            onHorizontalDragEnd: (d) =>
                _endPanelDrag(d.velocity.pixelsPerSecond.dx),
            onHorizontalDragCancel: () => _endPanelDrag(0),
            child: SizedBox(
              height: look.handleBarHeight,
              child: Row(
                children: [
                  const SizedBox(width: 48),
                  Expanded(child: Center(child: look.buildGrip(context))),
                  _control(context,
                      key: PhotoPanel.backKey,
                      label: 'Back to small photos',
                      icon: look.buildBackIcon(context),
                      onTap: widget.controller.stepBack),
                ],
              ),
            ),
          ),
          Expanded(
            child: KeyedSubtree(
              key: PhotoPanel.largeBrowserKey,
              child: look.buildLargeBrowser(
                context,
                count: photos.length,
                initialIndex: shown,
                itemBuilder: (context, i) => _largePhoto(photos, i),
                // Browsing never changes the selected photo (spec AC-07b).
                onShown: (i) => setState(() => _shown = i),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// One large photo, zoomable with two fingers (spec AC-07b). Only the shown
  /// photo and its neighbours are decoded, at the screen's width (sad §4).
  Widget _largePhoto(List<PhotoWithWords> photos, int i) {
    final id = photos[i].source.id;
    if ((i - (_shown ?? 0)).abs() > 1) {
      return SizedBox.expand(key: PhotoPanel.largePhotoKey(id));
    }
    return InteractiveViewer(
      key: PhotoPanel.largePhotoKey(id),
      transformationController:
          _zooms.putIfAbsent(id, TransformationController.new),
      maxScale: 5,
      child: SizedBox.expand(
          child: _preview(photos[i], _overlay.width, fit: BoxFit.contain)),
    );
  }

  /// On the way from half-open to full-open the start photo grows from its
  /// small place into its large one (spec AC-07).
  Widget _growingPhoto(BuildContext context, List<SourceWithWords> sources,
      List<PhotoWithWords> photos, Size panel, double p) {
    final look = _look;
    final i = _startIndex(photos);
    // Its small place in the half-open column, where sets are listed too.
    final at = math.max(0, sources.indexWhere((s) => s.source.id == photos[i].source.id));
    final offset = _column.hasClients ? _column.offset : 0.0;
    final top = MediaQuery.paddingOf(context).top * p;
    final small = Rect.fromLTWH(
      8,
      (look.handleBarHeight + at * look.smallPhotoExtent - offset + 4)
          .clamp(look.handleBarHeight, panel.height),
      look.halfOpenWidth - 16,
      look.smallPhotoExtent - 8,
    );
    final large = Rect.fromLTWH(0, top + look.handleBarHeight, panel.width,
        panel.height - top - look.handleBarHeight);
    return Positioned.fromRect(
      rect: Rect.lerp(small, large, Curves.easeInOut.transform(p))!,
      child: KeyedSubtree(
        key: PhotoPanel.growingPhotoKey,
        child: _preview(photos[i], look.halfOpenWidth),
      ),
    );
  }

  Widget _panel(BuildContext context, List<SourceWithWords> sources,
      List<PhotoWithWords> photos, double t) {
    final look = _look;
    final rect = _panelRect(t);
    final p = t <= 0.5 ? 0.0 : (t - 0.5) / 0.5;
    final half = p < 1;
    // A drag back that started on the full-open handle keeps the full-open
    // content, unseen, until it ends: removing the handle would drop the
    // drag and leave the panel between stops (spec AC-08).
    final keepFull = !half ||
        (_panelDragging && _dragStartStop == PanelStop.fullOpen);
    if (!keepFull && _shown != null) {
      _shown = null;
      _disposeZooms();
    }
    // The half-open size from exact numbers: one that differs only in
    // rounding would still count as a new size.
    Widget content = look.buildPanelSurface(
      context,
      fullness: p,
      halfOpenAt: p == 0 ? Offset.zero : _panelRect(0.5).topLeft - rect.topLeft,
      halfOpenSize: Size(_halfWidth, _page.height),
      child: ClipRect(
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (half)
              Opacity(
                key: const ValueKey('half'),
                opacity: 1 - p,
                child: OverflowBox(
                  alignment: Alignment.topLeft,
                  minWidth: look.halfOpenWidth,
                  maxWidth: look.halfOpenWidth,
                  child: _halfContent(context, sources),
                ),
              ),
            if (p > 0 && p < 1 && photos.isNotEmpty && !_revealsNotes)
              _growingPhoto(context, sources, photos, rect.size, p),
            if (keepFull && photos.isNotEmpty && !_revealsNotes)
              Offstage(
                key: const ValueKey('full'),
                offstage: half,
                child: _fullContent(context, photos),
              ),
          ],
        ),
      ),
    );
    // In half-open a horizontal drag anywhere on the panel moves it; a
    // vertical one scrolls the column. Always in the tree, so a drag that
    // reaches full-open is not dropped on the way.
    final dragsPanel = half || _panelDragging;
    content = GestureDetector(
      onHorizontalDragStart: dragsPanel ? (_) => _beginPanelDrag() : null,
      onHorizontalDragUpdate: dragsPanel ? (d) => _panelDragBy(d.delta.dx) : null,
      onHorizontalDragEnd: dragsPanel
          ? (d) => _endPanelDrag(d.velocity.pixelsPerSecond.dx)
          : null,
      onHorizontalDragCancel: dragsPanel ? () => _endPanelDrag(0) : null,
      child: content,
    );
    return Positioned.fromRect(
      rect: rect,
      child: KeyedSubtree(key: PhotoPanel.panelKey, child: content),
    );
  }

  /// Past half-open with Notes: the Notes page, laid out on the whole
  /// screen as it will be pushed, shown inside the widening panel and fading
  /// in, so the panel turns into the page (owner, 2026-10-15). It ignores
  /// touches: the drag stays the panel's.
  Widget _notesReveal(BuildContext context, double t) {
    final p = (t - 0.5) / 0.5;
    return Positioned.fill(
      child: IgnorePointer(
        child: ClipRect(
          clipper: _RectClipper(_panelRect(t)),
          child: Opacity(
            opacity: Curves.easeOut.transform(p.clamp(0.0, 1.0)),
            // The navigator's insets, as the pushed page gets them: the
            // panel sits in a body whose top bar took the status bar's.
            child: MediaQuery(
              data: MediaQuery.of(Navigator.of(context).context),
              child: KeyedSubtree(
                key: PhotoPanel.notesRevealKey,
                child: widget.notesPage!(widget.controller.selectedId),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _tab(BuildContext context, List<SourceWithWords> photos, double t) {
    final look = _look;
    final tabSize = tabSizeFor(look, photos.length);
    final top = _tabTop(_page.size, tabSize);
    final hidden = look.hidesTabWhileScrolling && _listScrolling;
    final open = t > 0;
    final page = _page;
    return Positioned(
      left: _panelRect(t).left - tabSize.width,
      top: page.top + top,
      width: tabSize.width,
      height: tabSize.height,
      child: Opacity(
        // The tab leaves with the panel's edge as it opens.
        opacity: (1 - t / 0.5).clamp(0.0, 1.0),
        child: AnimatedOpacity(
          opacity: hidden ? 0 : 1,
          duration: const Duration(milliseconds: 150),
          child: IgnorePointer(
            ignoring: hidden || (open && _tabDrag != _TabDrag.open),
            child: AbsorbPointer(
              absorbing: widget.busy,
              // One node for a screen reader: "Collection photos, N" ("Collection
              // sources, N" with a set among them), whose double-tap opens
              // half-open, except while busy (spec AC-18, AC-21).
              child: Semantics(
                container: true,
                button: true,
                label: photos.every((p) => p.isPhoto)
                    ? 'Collection photos, ${photos.length}'
                    : 'Collection sources, ${photos.length}',
                excludeSemantics: true,
                onTap: widget.busy || open
                    ? null
                    : () => _open(PanelStop.halfOpen),
                child: GestureDetector(
                  key: PhotoPanel.tabKey,
                  behavior: HitTestBehavior.opaque,
                  onTap: () => _open(PanelStop.halfOpen),
                  onPanDown: _onTabPanDown,
                  onPanStart: (_) => _onTabPanStart(top),
                  onPanUpdate: _onTabPanUpdate,
                  onPanEnd: (d) => _onTabPanEnd(
                      page.size, tabSize, d.velocity.pixelsPerSecond.dx),
                  onPanCancel: () => _onTabPanEnd(page.size, tabSize, 0),
                  child:
                      look.buildTab(context, photos: photos, preview: _preview),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOverlay(BuildContext context, List<SourceWithWords> sources,
          List<PhotoWithWords> photos) =>
      AnimatedBuilder(
        animation: _openness,
        builder: (context, _) {
          final t = _openness.value;
          return BackdropGroup(
            backdropKey: _backdropKey,
            child: Stack(
              children: [
                // Kept in the tree during a drag that started on it, so the
                // drag is not cancelled when the tab fades out.
                if (t < 0.5 || _tabDrag == _TabDrag.open)
                  KeyedSubtree(
                      key: const ValueKey('tab'),
                      child: _tab(context, sources, t)),
                if (t > 0)
                  KeyedSubtree(
                      key: const ValueKey('panel'),
                      child: _panel(context, sources, photos, t)),
                if (t > 0.5 && _revealsNotes)
                  KeyedSubtree(
                      key: const ValueKey('notes'),
                      child: _notesReveal(context, t)),
              ],
            ),
          );
        },
      );

  /// Whether the main screen's route is on top; under another route the tab
  /// is covered, Android gets no rectangle and the panel closes (ADR-0001).
  bool _routeIsCurrent = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (!identical(route, _route)) {
      _route?.secondaryAnimation?.removeStatusListener(_onRouteCovered);
      _route = route;
      route?.secondaryAnimation?.addStatusListener(_onRouteCovered);
    }
    _routeIsCurrent = ModalRoute.isCurrentOf(context) ?? true;
    if (!_routeIsCurrent && widget.controller.isOpen && !_inNotes) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.controller.close();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final sources = ref.watch(sourcesWithWordsProvider);
    final photos = ref.watch(photosWithWordsProvider);
    ref.watch(photoPreloaderProvider); // kept alive while the panel lives
    _hasPhotos = photos.isNotEmpty;
    _schedulePreload(sources);
    // The last photo went while full-open, a set is left: back to half-open
    // (spec AC-15, AC-21).
    if (!_hasPhotos &&
        sources.isNotEmpty &&
        widget.controller.stop == PanelStop.fullOpen) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_hasPhotos) widget.controller.setStop(PanelStop.halfOpen);
      });
    }
    return OverlayPortal.overlayChildLayoutBuilder(
      controller: _portal,
      overlayChildBuilder: (context, info) {
        final origin =
            MatrixUtils.transformPoint(info.childPaintTransform, Offset.zero);
        _page = origin & info.childSize;
        _overlay = info.overlaySize;
        _devicePixelRatio = MediaQuery.devicePixelRatioOf(context);
        _want(_exclusionFor(sources));
        if (sources.isEmpty || widget.hidden) return const SizedBox.shrink();
        return _buildOverlay(context, sources, photos);
      },
      child: const SizedBox.expand(),
    );
  }
}

enum _TabDrag { none, undecided, move, open }

/// Clips to one rectangle of the overlay: the panel's, this frame.
class _RectClipper extends CustomClipper<Rect> {
  const _RectClipper(this.rect);

  final Rect rect;

  @override
  Rect getClip(Size size) => rect;

  @override
  bool shouldReclip(_RectClipper oldClipper) => oldClipper.rect != rect;
}

/// How many of [items] before [end] are photos.
int _photoCount(List<SourceWithWords> items, int end) =>
    items.take(end).where((i) => i.isPhoto).length;
