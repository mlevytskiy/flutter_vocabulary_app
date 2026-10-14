import 'package:flutter/material.dart';

import '../../../core/models/session_source.dart';
import '../widgets/quizlet_logo_icon.dart';

/// A source with words that has no picture, drawn in the photo panel where a
/// photo would be (side-panel-sources, spec AC-21): its kind's icon and, in
/// the half-open column, its name. [mini] is the tab's small preview: the
/// icon only.
///
/// Each non-photo kind the panel lists (`panelSourceKinds`) needs a case in
/// [_icon] and in [semanticsLabel].
class SourceTile extends StatelessWidget {
  const SourceTile({super.key, required this.source, this.mini = false});

  final SessionSource source;
  final bool mini;

  /// What a screen reader says for this source in the half-open column.
  static String semanticsLabel(SessionSource source) => switch (source.kind) {
        SourceKind.set => 'Quizlet set ${source.name ?? ''}'.trim(),
        SourceKind.subtitles => 'Film ${source.name ?? ''}'.trim(),
        SourceKind.photo => 'Photo',
      };

  static Widget _icon(SessionSource source, double size, Color color) =>
      switch (source.kind) {
        SourceKind.set => QuizletLogoIcon(size: size, color: color),
        // No poster is kept on the phone, so a film is its icon (AC-22).
        SourceKind.subtitles => Icon(Icons.movie_outlined, size: size, color: color),
        SourceKind.photo => Icon(Icons.photo_outlined, size: size, color: color),
      };

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = scheme.onSurfaceVariant;
    return ExcludeSemantics(
      child: ColoredBox(
        color: scheme.surfaceContainerHighest,
        child: SizedBox.expand(
          child: mini
              ? Center(child: _icon(source, 22, color))
              : Padding(
                  padding: const EdgeInsets.all(6),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _icon(source, 32, color),
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
}
