import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import 'looks/looks.dart';
import 'looks/photo_panel_look.dart';
import 'photo_panel_controller.dart';
import 'photo_preview.dart';
import 'photos_with_words.dart';

/// The photo tab and photo panel over the main screen's words page
/// (side-bar-for-main-screen, ADR-0001).
///
/// Mounted by the main screen as a `Positioned.fill` child over its word list;
/// that child only marks the words page's place. The tab and the panel are
/// drawn through an [OverlayPortal] above the route, so a touch that starts on
/// them is hit-tested first and never reaches the rows or the pager (spec
/// AC-13, AC-14). With no photo with words nothing is drawn (spec AC-02).
class PhotoPanel extends ConsumerStatefulWidget {
  const PhotoPanel({
    super.key,
    required this.controller,
    this.busy = false,
    this.bottomReserve = 0,
    this.scrollController,
    this.onSelected,
    @visibleForTesting this.look,
  });

  static const tabKey = Key('photo-panel-tab');

  final PhotoPanelController controller;

  /// The screen is analysing a photo: the tab ignores touches (spec AC-17).
  final bool busy;

  /// Height kept free at the bottom of the words page for the floating
  /// buttons and a SnackBar; the tab never goes lower (spec AC-01).
  final double bottomReserve;

  /// The word list's controller; its scrolling hides the tab for a look that
  /// asks for it (spec AC-19).
  final ScrollController? scrollController;

  /// Called after the selected photo changes, with the new one or null; the
  /// screen highlights its rows and jumps to the first (spec AC-04, AC-05).
  final ValueChanged<String?>? onSelected;

  /// Overrides the design variant's look; tests only.
  final PhotoPanelLook? look;

  @override
  ConsumerState<PhotoPanel> createState() => _PhotoPanelState();
}

class _PhotoPanelState extends ConsumerState<PhotoPanel> {
  final _portal = OverlayPortalController();

  /// The tab's top while it is dragged up or down, unclamped.
  double? _dragTop;

  /// How the current drag on the tab was read: up/down moves the tab, left
  /// opens the panel; one drag never does both (spec AC-14).
  _TabDrag _tabDrag = _TabDrag.none;
  double _tabStartTop = 0;

  ScrollPosition? _watchedPosition;
  bool _listScrolling = false;

  PhotoPanelLook get _look =>
      widget.look ?? lookFor(ref.watch(photoPanelVariantProvider));

  @override
  void initState() {
    super.initState();
    _portal.show();
    WidgetsBinding.instance.addPostFrameCallback((_) => _watchScrolling());
  }

  @override
  void didUpdateWidget(PhotoPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.scrollController != widget.scrollController) _watchScrolling();
  }

  @override
  void dispose() {
    _watchedPosition?.isScrollingNotifier.removeListener(_onScrolling);
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
    if (scrolling != _listScrolling && mounted) setState(() => _listScrolling = scrolling);
  }

  // The tab's height on the words page.

  double _tabTop(Size page, Size tab) => PhotoTabTopNotifier.clamp(
        _dragTop ?? ref.watch(photoTabTopProvider),
        min: 0,
        max: page.height - widget.bottomReserve - tab.height,
      );

  /// The first movement past the touch slop decides the direction.
  void _onTabPanStart(double currentTop) {
    _tabDrag = _TabDrag.undecided;
    _tabStartTop = currentTop;
  }

  void _onTabPanUpdate(DragUpdateDetails d) {
    if (_tabDrag == _TabDrag.undecided) {
      if (d.delta.dy.abs() > d.delta.dx.abs()) {
        _tabDrag = _TabDrag.move;
        _dragTop = _tabStartTop;
      } else {
        _tabDrag = d.delta.dx < 0 ? _TabDrag.open : _TabDrag.none;
      }
    }
    if (_tabDrag == _TabDrag.move) {
      setState(() => _dragTop = _dragTop! + d.delta.dy);
    }
  }

  void _onTabPanEnd(Size page, Size tab) {
    if (_tabDrag == _TabDrag.move) {
      final top = PhotoTabTopNotifier.clamp(
        _dragTop!,
        min: 0,
        max: page.height - widget.bottomReserve - tab.height,
      );
      ref.read(photoTabTopProvider.notifier).set(top);
      setState(() => _dragTop = null);
    }
    _tabDrag = _TabDrag.none;
  }

  Widget _preview(PhotoWithWords photo, double width) => PhotoPreview(
        key: ValueKey('photo-panel-preview-${photo.source.id}-$width'),
        source: photo.source,
        width: width,
        placeholder: _look.buildPlaceholder,
      );

  Widget _buildOverlay(BuildContext context, Rect page, List<PhotoWithWords> photos) {
    final look = _look;
    final tabSize = tabSizeFor(look, photos.length);
    final top = _tabTop(page.size, tabSize);
    final hidden = look.hidesTabWhileScrolling && _listScrolling;
    return Stack(
      children: [
        Positioned(
          left: page.right - tabSize.width,
          top: page.top + top,
          width: tabSize.width,
          height: tabSize.height,
          child: AnimatedOpacity(
            opacity: hidden ? 0 : 1,
            duration: const Duration(milliseconds: 150),
            child: IgnorePointer(
              ignoring: hidden,
              child: AbsorbPointer(
                absorbing: widget.busy,
                child: GestureDetector(
                  key: PhotoPanel.tabKey,
                  behavior: HitTestBehavior.opaque,
                  onPanStart: (_) => _onTabPanStart(top),
                  onPanUpdate: _onTabPanUpdate,
                  onPanEnd: (_) => _onTabPanEnd(page.size, tabSize),
                  onPanCancel: () => _onTabPanEnd(page.size, tabSize),
                  child: look.buildTab(context, photos: photos, preview: _preview),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final photos = ref.watch(photosWithWordsProvider);
    return OverlayPortal.overlayChildLayoutBuilder(
      controller: _portal,
      overlayChildBuilder: (context, info) {
        if (photos.isEmpty) return const SizedBox.shrink();
        final origin = MatrixUtils.transformPoint(info.childPaintTransform, Offset.zero);
        return _buildOverlay(context, origin & info.childSize, photos);
      },
      child: const SizedBox.expand(),
    );
  }
}

enum _TabDrag { none, undecided, move, open }
