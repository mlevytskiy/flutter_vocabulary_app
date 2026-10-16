import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'looks/look_a.dart';
import 'photo_panel_controller.dart';
import 'photos_with_words.dart';

/// What a screen that hosts the [PhotoPanel] over its words keeps and does:
/// the main screen's words page (side-bar-for-main-screen) and the Words
/// screen (words-photo-panel). Moved here from the main screen's `State`.
mixin PhotoPanelHost<T extends ConsumerStatefulWidget> on ConsumerState<T> {
  /// side-bar-for-main-screen: the photo panel's stop and selected photo
  /// (sad §4 "State placement"); read for Back and the rows' highlight.
  final PhotoPanelController photoPanel = PhotoPanelController();

  void _onPhotoPanelChanged() {
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    photoPanel.addListener(_onPhotoPanelChanged);
  }

  @override
  void dispose() {
    photoPanel.dispose();
    super.dispose();
  }

  /// While the photo panel is open the main screen is only for looking: a
  /// touch on a row, the top bar or the floating buttons closes the panel
  /// and does nothing else; the list still scrolls (spec AC-11). Closed,
  /// [child] is exactly as before.
  Widget closesOpenPhotoPanel(Widget child) {
    final open = photoPanel.isOpen;
    return GestureDetector(
      onTap: open ? photoPanel.close : null,
      child: AbsorbPointer(absorbing: open, child: child),
    );
  }

  /// The selected photo's rows and the look's highlight for them (spec AC-04);
  /// with nothing selected every row is today's row.
  (Set<int>, Decoration?) photoHighlight(List<SourceWithWords> photos) {
    final id = photoPanel.selectedId;
    if (id == null) return (const {}, null);
    final rows = photos.where((p) => p.source.id == id).firstOrNull?.rows;
    if (rows == null) return (const {}, null);
    return (rows.toSet(), const LookA().rowHighlight(context));
  }

  /// The top bar, which an open photo panel owns like the rest of the screen
  /// (spec AC-11).
  PreferredSizeWidget photoPanelGuardedAppBar(PreferredSizeWidget appBar) =>
      PreferredSize(
        preferredSize: appBar.preferredSize,
        child: closesOpenPhotoPanel(appBar),
      );
}
