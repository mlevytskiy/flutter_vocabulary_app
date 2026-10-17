import 'package:flutter/material.dart';

import '../../core/models/tag_kind.dart';
import '../../core/services/collection_search_scope.dart';
import '../../core/theme/app_theme.dart';

/// "Match outside" (collections-search AC-05 – AC-08): a sheet at the bottom
/// of the Collections search with the matches that are not directly in the
/// open folder. It peeks at [peekSize] of the body with the counts and the
/// folders they are in; dragged up, or its header tapped, it opens to
/// [openSize] on the route — the folder tree pruned to those matches, with
/// the open folder marked "You are here".
class MatchOutsideSheet extends StatefulWidget {
  const MatchOutsideSheet({
    super.key,
    required this.split,
    required this.route,
    required this.folders,
    required this.query,
    required this.autoOpen,
    required this.autoOpenKey,
    required this.onOpenFolder,
    required this.onOpenCollection,
  });

  static const peekSize = 0.2;
  static const openSize = 0.74;
  static const title = 'Match outside';
  static const hereText = 'You are here';
  static const nameMatchesText = 'Folder name matches';

  final SearchSplit split;
  final List<RouteRow> route;
  final List<SearchFolder> folders;

  /// The search text, bold in the names it matches.
  final String query;

  /// Open by itself, once per [autoOpenKey] (AC-08).
  final bool autoOpen;
  final String autoOpenKey;

  /// A folder, or "Collections" (null), on the route.
  final ValueChanged<String?> onOpenFolder;
  final ValueChanged<String> onOpenCollection;

  /// "5 deeper, 2 elsewhere", zero parts left out (AC-05).
  static String summaryOf(SearchSplit split) => [
        if (split.deeper > 0) '${split.deeper} deeper',
        if (split.elsewhere > 0) '${split.elsewhere} elsewhere',
      ].join(', ');

  @override
  State<MatchOutsideSheet> createState() => _MatchOutsideSheetState();
}

class _MatchOutsideSheetState extends State<MatchOutsideSheet> {
  final _controller = DraggableScrollableController();
  String? _autoOpened;
  bool _open = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_sized);
    _maybeAutoOpen();
  }

  @override
  void didUpdateWidget(MatchOutsideSheet old) {
    super.didUpdateWidget(old);
    _maybeAutoOpen();
  }

  @override
  void dispose() {
    _controller.removeListener(_sized);
    _controller.dispose();
    super.dispose();
  }

  void _sized() {
    final open = _controller.size > 0.4;
    if (open != _open) setState(() => _open = open);
  }

  void _maybeAutoOpen() {
    if (!widget.autoOpen || _autoOpened == widget.autoOpenKey) return;
    _autoOpened = widget.autoOpenKey;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _animateTo(MatchOutsideSheet.openSize);
    });
  }

  void _animateTo(double size) {
    if (!_controller.isAttached) return;
    _controller.animateTo(
      size,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
  }

  void _toggle() => _animateTo(
      _open ? MatchOutsideSheet.peekSize : MatchOutsideSheet.openSize);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DraggableScrollableSheet(
      key: const Key('match-outside'),
      controller: _controller,
      initialChildSize: MatchOutsideSheet.peekSize,
      minChildSize: MatchOutsideSheet.peekSize,
      maxChildSize: MatchOutsideSheet.openSize,
      snap: true,
      builder: (context, scroll) => Material(
        color: scheme.surface,
        elevation: 8,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
        ),
        clipBehavior: Clip.antiAlias,
        child: ListView(
          controller: scroll,
          padding: const EdgeInsets.only(bottom: 16),
          children: [
            _header(context),
            for (final row in widget.route) _row(context, row),
          ],
        ),
      ),
    );
  }

  Widget _header(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final muted = AppDecor.of(context).muted;
    final places = outsidePlaces(widget.route);
    return InkWell(
      key: const Key('match-outside-header'),
      onTap: _toggle,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: scheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  MatchOutsideSheet.title,
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    MatchOutsideSheet.summaryOf(widget.split),
                    style: TextStyle(fontSize: 12, color: muted),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  _open ? 'Hide' : 'Show route',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: scheme.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 26,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: places.length,
                separatorBuilder: (_, __) => const SizedBox(width: 6),
                itemBuilder: (context, i) => _placeChip(context, places[i]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// A folder the outside matches are in, its path muted and its own name
  /// in full.
  Widget _placeChip(BuildContext context, String? folderId) {
    final scheme = Theme.of(context).colorScheme;
    final parts = folderPathOf(folderId, widget.folders).split(' / ');
    final last = parts.removeLast();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
        border: Border.all(color: scheme.outlineVariant),
        borderRadius: BorderRadius.circular(13),
      ),
      child: Text.rich(
        TextSpan(children: [
          if (parts.isNotEmpty)
            TextSpan(
              text: '${parts.join(' / ')} / ',
              style: TextStyle(color: AppDecor.of(context).muted),
            ),
          TextSpan(text: last),
        ]),
        style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700),
      ),
    );
  }

  Widget _row(BuildContext context, RouteRow row) {
    final scheme = Theme.of(context).colorScheme;
    final muted = AppDecor.of(context).muted;
    final lineColor = scheme.primary.withValues(alpha: 0.45);
    final nameStyle = TextStyle(
      fontSize: 13.5,
      fontWeight: row.kind == RouteRowKind.collection
          ? FontWeight.w800
          : FontWeight.w700,
      color: row.isHere ? muted : scheme.onSurface,
    );

    final Widget marker;
    final Widget name;
    String? subtitle;
    Key key;
    VoidCallback? onTap;
    switch (row.kind) {
      case RouteRowKind.root:
        key = const Key('route-root');
        marker = Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: scheme.primary,
            borderRadius: BorderRadius.circular(7),
          ),
          child: Icon(Icons.folder, size: 15, color: scheme.onPrimary),
        );
        name = _named('Collections', row.isHere,
            nameStyle.copyWith(color: scheme.onSurface));
        if (row.isHere) subtitle = 'Matches at the top level are in the list';
        onTap = row.isHere ? null : () => widget.onOpenFolder(null);
      case RouteRowKind.folder:
        final f = row.folder!;
        key = Key('route-folder-${f.id}');
        marker = row.isHere
            ? Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: muted, width: 2),
                ),
              )
            : Icon(Icons.folder_outlined, size: 21, color: scheme.primary);
        name = _named(
          f.name,
          row.isHere,
          nameStyle,
          highlight: row.nameMatches,
        );
        if (row.isHere) {
          subtitle = 'Matches directly here are in the list';
        } else if (row.nameMatches) {
          subtitle = MatchOutsideSheet.nameMatchesText;
        }
        onTap = row.isHere ? null : () => widget.onOpenFolder(f.id);
      case RouteRowKind.collection:
        final c = row.collection!;
        key = Key('route-collection-${c.id}');
        marker = Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: scheme.primary,
            shape: BoxShape.circle,
            border: Border.all(color: scheme.surface, width: 2),
            boxShadow: [BoxShadow(color: lineColor, spreadRadius: 2)],
          ),
        );
        name = _named(c.name, false, nameStyle, highlight: true);
        final tags = [...c.tagsOf(TagKind.origin), ...c.tagsOf(TagKind.topic)];
        if (tags.isNotEmpty) subtitle = tags.join(', ');
        onTap = () => widget.onOpenCollection(c.id);
    }

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(width: 10),
          for (final cell in row.rail)
            SizedBox(
              width: 20,
              child: CustomPaint(painter: _RailPainter(cell, lineColor)),
            ),
          Expanded(
            child: InkWell(
              key: key,
              onTap: onTap,
              borderRadius: BorderRadius.circular(10),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(2, 8, 12, 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox.square(
                      dimension: 24,
                      child: Center(child: marker),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: name,
                          ),
                          if (subtitle != null)
                            Text(
                              subtitle,
                              style: TextStyle(fontSize: 11.5, color: muted),
                            ),
                        ],
                      ),
                    ),
                    if (row.kind != RouteRowKind.collection && row.count > 0)
                      Padding(
                        padding: const EdgeInsets.only(top: 4, left: 6),
                        child: Text(
                          '${row.count}',
                          style: TextStyle(
                            fontSize: 11,
                            color: muted,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// A name, the query bold in it when [highlight], and the "You are here"
  /// pill when [here].
  Widget _named(String text, bool here, TextStyle style,
      {bool highlight = false}) {
    final scheme = Theme.of(context).colorScheme;
    final q = widget.query.trim().toLowerCase();
    final at = highlight && q.isNotEmpty ? text.toLowerCase().indexOf(q) : -1;
    return Text.rich(
      TextSpan(children: [
        if (at < 0)
          TextSpan(text: text)
        else ...[
          TextSpan(text: text.substring(0, at)),
          TextSpan(
            text: text.substring(at, at + q.length),
            style: TextStyle(
              color: scheme.primary,
              fontWeight: FontWeight.w900,
            ),
          ),
          TextSpan(text: text.substring(at + q.length)),
        ],
        if (here)
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: Container(
              margin: const EdgeInsets.only(left: 6),
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
              decoration: BoxDecoration(
                color: scheme.secondaryContainer,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                MatchOutsideSheet.hereText,
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  color: scheme.onSecondaryContainer,
                ),
              ),
            ),
          ),
      ]),
      style: style,
    );
  }
}

/// One column of a route row's rail: a line passing down, this row's
/// branch (a tee, or the last one's elbow), or nothing.
class _RailPainter extends CustomPainter {
  _RailPainter(this.cell, this.color);

  final RailCell cell;
  final Color color;

  /// The branch meets the row's marker this far down.
  static const _branchY = 20.0;

  @override
  void paint(Canvas canvas, Size size) {
    if (cell == RailCell.none) return;
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2;
    // Under the centre of the parent row's marker (2 + 24 / 2 in).
    const x = 14.0;
    final bottom = cell == RailCell.elbow ? _branchY : size.height;
    canvas.drawLine(const Offset(x, 0), Offset(x, bottom), paint);
    if (cell != RailCell.pass) {
      canvas.drawLine(
          const Offset(x, _branchY), Offset(size.width, _branchY), paint);
    }
  }

  @override
  bool shouldRepaint(_RailPainter old) =>
      old.cell != cell || old.color != color;
}
