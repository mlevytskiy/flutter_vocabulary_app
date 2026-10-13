import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/dialogues/dialogue_match.dart';
import '../../../core/models/film_dialogue.dart';
import '../../../core/models/story_run.dart';
import '../../../core/models/word_pair.dart';
import '../../../core/providers.dart';
import '../../mnemonic_story/widgets/story_picture.dart';

/// One film dialogue on the main screen's pager (get-words-from-subtitles-
/// improvment SCR-02): its scene picture once drawn, its lines with every
/// place of every dialogue word in bold, and the list of those words with
/// their translation and definition. Read only; it shows the rows as they are
/// now, so it follows the learner's edits (AC-11).
class DialoguePage extends StatelessWidget {
  const DialoguePage({super.key, required this.dialogue, required this.words});

  final FilmDialogue dialogue;

  /// The session's rows; the dialogue's are found by row id.
  final List<WordPair> words;

  @override
  Widget build(BuildContext context) {
    final byId = {for (final w in words) w.rowId: w};
    final dialogueWords = [
      for (final id in dialogue.wordRowIds)
        if (byId[id] case final w? when !w.isEmpty) w,
    ];
    final textTheme = Theme.of(context).textTheme;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (dialogue.scenePictureRunId case final runId?)
          ScenePicture(runId: runId),
        for (final line in dialogue.lines)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text.rich(
              TextSpan(children: boldSpans(line, dialogueWords)),
              style: textTheme.bodyLarge,
            ),
          ),
        const Divider(height: 32),
        for (final w in dialogueWords)
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(w.word, style: textTheme.titleSmall),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (w.translation.trim().isNotEmpty) Text(w.translation),
                if (w.definition.trim().isNotEmpty) Text(w.definition),
              ],
            ),
          ),
      ],
    );
  }
}

/// [line] split into spans, every place of every word in [words] bold
/// (AC-05 rule); overlapping places merge.
List<TextSpan> boldSpans(String line, List<WordPair> words) {
  final places = [
    for (final w in words) ...matchPlaces(line, w.word),
  ]..sort((a, b) => a.start.compareTo(b.start));
  final spans = <TextSpan>[];
  var at = 0;
  for (final p in places) {
    if (p.end <= at) continue;
    final start = p.start < at ? at : p.start;
    if (start > at) spans.add(TextSpan(text: line.substring(at, start)));
    spans.add(TextSpan(
        text: line.substring(start, p.end),
        style: const TextStyle(fontWeight: FontWeight.bold)));
    at = p.end;
  }
  if (at < line.length) spans.add(TextSpan(text: line.substring(at)));
  return spans;
}

/// A dialogue's scene picture: the last picture its scene run drew, from the
/// phone's picture store. Nothing while the run has none.
class ScenePicture extends ConsumerWidget {
  const ScenePicture({super.key, required this.runId});

  final String runId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder<StoryRun?>(
      future: ref.read(storyRunStoreProvider.future).then((s) => s.byId(runId)),
      builder: (context, snapshot) {
        final picture = snapshot.data?.steps
            .where((s) =>
                s.role == 'picture' &&
                s.outcome == 'done' &&
                s.picturePath != null)
            .lastOrNull;
        if (picture == null) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: StoryPicture(runId: runId, attempt: picture.attempt),
        );
      },
    );
  }
}
