import 'package:flutter/material.dart';

import '../../../core/models/session_source.dart';
import '../widgets/quizlet_logo_icon.dart';

/// A source with words that has no picture, drawn in the photo panel where a
/// photo would be (side-panel-sources, spec AC-21): its kind's icon and, in
/// the half-open column, "N words" beside the icon and its name under them
/// (owner, 2026-10-15). A film with a poster is its poster instead of the
/// icon and the count, its name over it. [mini] is the tab's small preview:
/// the icon only.
///
/// Each non-photo kind the panel lists (`panelSourceKinds`) needs a case in
/// [_icon] and in [semanticsLabel].
class SourceTile extends StatelessWidget {
  const SourceTile(
      {super.key, required this.source, this.mini = false, this.wordCount});

  final SessionSource source;
  final bool mini;

  /// How many word rows come from the source, shown beside its icon; null
  /// shows the icon alone.
  final int? wordCount;

  static String wordCountLabel(int count) =>
      count == 1 ? '1 word' : '$count words';

  /// What a screen reader says for this source in the half-open column.
  static String semanticsLabel(SessionSource source) => switch (source.kind) {
        SourceKind.set => 'Quizlet set ${source.name ?? ''}'.trim(),
        SourceKind.subtitles => 'Film ${source.name ?? ''}'.trim(),
        SourceKind.photo => 'Photo',
      };

  static Widget _icon(SessionSource source, double size, Color color) =>
      switch (source.kind) {
        SourceKind.set => QuizletLogoIcon(size: size, color: color),
        // A film without a poster is its icon (AC-22): subtitles, CC.
        SourceKind.subtitles =>
          Icon(Icons.closed_caption_outlined, size: size, color: color),
        SourceKind.photo => Icon(Icons.photo_outlined, size: size, color: color),
      };

  /// The film's poster address, or null for a set, a photo, or a film
  /// imported before posters were kept.
  String? get _poster =>
      source.kind == SourceKind.subtitles ? source.url : null;

  /// The poster filling the tile; the icon tile while it loads or when it
  /// fails, so a poster never leaves a broken image.
  Widget _posterTile(BuildContext context, String url, Widget iconTile) {
    final image = Image.network(
      url,
      key: const Key('source-tile-poster'),
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      gaplessPlayback: true,
      errorBuilder: (context, _, __) => iconTile,
      frameBuilder: (context, child, frame, sync) =>
          frame == null && !sync ? iconTile : child,
    );
    if (mini) return ExcludeSemantics(child: image);
    return ExcludeSemantics(
      child: Stack(
        fit: StackFit.expand,
        children: [
          image,
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: DecoratedBox(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0x00000000), Color(0xB3000000)],
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(6, 14, 6, 5),
                child: Text(
                  source.name ?? '',
                  key: const Key('source-tile-name'),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    height: 1.2,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final poster = _poster;
    final iconTile = _iconTile(context);
    return poster == null ? iconTile : _posterTile(context, poster, iconTile);
  }

  Widget _iconTile(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = scheme.onSurfaceVariant;
    return ExcludeSemantics(
      child: ColoredBox(
        color: scheme.surfaceContainerHighest,
        child: SizedBox.expand(
          child: mini
              // The tab's mosaic draws minis smaller than the icon.
              ? LayoutBuilder(
                  builder: (context, box) => Center(
                      child: _icon(
                          source,
                          (box.biggest.shortestSide * 0.62).clamp(8.0, 22.0),
                          color)))
              : Padding(
                  padding: const EdgeInsets.all(6),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _iconAndCount(color, scheme.onSurface),
                      const SizedBox(height: 6),
                      Text(
                        source.name ?? '',
                        key: const Key('source-tile-name'),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: scheme.onSurface,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          height: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }

  /// The kind's icon and, with [wordCount], "N words" beside it.
  Widget _iconAndCount(Color iconColor, Color textColor) {
    final count = wordCount;
    if (count == null) return _icon(source, 32, iconColor);
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _icon(source, 22, iconColor),
          const SizedBox(width: 4),
          Text(
            wordCountLabel(count),
            key: const Key('source-tile-count'),
            maxLines: 1,
            style: TextStyle(
              color: textColor,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
