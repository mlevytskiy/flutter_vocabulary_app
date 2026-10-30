import 'dart:convert';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/dialogues/dialogue_rules.dart' show ImportedDialogue;
import '../../core/models/vocab_word.dart';
import '../../core/models/word_origin.dart';
import '../../core/models/word_pair.dart';
import '../../core/providers.dart';
import '../../core/models/subtitle_import_options.dart';
import '../../core/services/subtitle_parser.dart';
import '../../core/services/subtitle_search_service.dart';
import '../../core/services/subtitle_word_counter.dart';
import '../../core/services/subtitle_words_service.dart';
import '../../core/words/word_origin_rules.dart';
import 'widgets/subtitle_progress_dialog.dart';
import 'widgets/subtitle_search_dialog.dart';
import 'widgets/subtitle_import_dialog.dart';
import 'widgets/vocab_result_dialog.dart';

/// What the learner reads when a subtitle import ends without words (spec
/// AC-10, AC-12, AC-14).
abstract final class SubtitleImportMessages {
  static const noEnglish = 'No English subtitles to read in this file.';
  static const tooManyImports = 'Too many subtitle imports. Wait a few minutes and try again.';
  static const notPicked = "The words couldn't be picked. Try again from the + button.";
}

/// One subtitle import, from the speed dial to Done (words-from-subtitles
/// sad §6 F1, F3, F4): the import dialog, then — with its values recorded in
/// Settings while "Update with each import" is on — the progress dialog
/// ([showSubtitleProgressDialog]: the picked words with their context lines,
/// swipeable, translations as skeletons until they arrive) while the phone picks the most frequent words the level
/// does not know yet ([SubtitleWordCounter]) and the translator chosen in
/// Settings translates them — Google Translate on the phone, with the phone's
/// context line, or the AI on the Worker — then the results dialog. Only Done changes the session, through [addWords];
/// every failure closes the progress dialog with its message and leaves the
/// session as it was. If another collection was opened since Start, the kept
/// words go to the one the import started in, through [addWordsTo]
/// (collections-screen ADR-0006, AC-11). With the AI translating and "Get dialogues from
/// subtitles" on, the import also asks for film dialogues; they ride with the result, unseen by
/// the results dialog, and right after [addWords] go to [addDialogues] with
/// the number of words kept, so one save holds both
/// (get-words-from-subtitles-improvment AC-02, AC-03). [addWords] also gets
/// the film's title ([subtitleFilmTitle]), the source the screen records the
/// kept rows under (side-panel-sources, spec AC-22), and its poster's address
/// for the photo panel's tile (owner, 2026-10-15): the one found by name, or,
/// for a picked file, one looked up by the file's name while the dialogs are
/// open ([findSubtitlePoster]); null when none is found in time. Both get
/// the [SubtitleFilmRow] that gives each row built from a kept word its movie
/// origin, time and context (word-context AC-06 – AC-09).
Future<void> runSubtitleImport({
  required BuildContext context,
  required WidgetRef ref,
  required String? Function() currentCollectionId,
  required List<String> Function() collectionWords,
  required void Function(List<VocabWord> words, String film, String? poster, SubtitleFilmRow filmRow) addWords,
  void Function(List<ImportedDialogue> dialogues, int keptCount)? addDialogues,
  Future<void> Function(String collectionId, List<VocabWord> words, String film, String? poster,
          List<ImportedDialogue> dialogues, SubtitleFilmRow filmRow)?
      addWordsTo,
  Future<XFile?> Function()? pickFile,
}) async {
  final prefsNotifier = ref.read(subtitleImportPrefsProvider.notifier);
  await prefsNotifier.loaded;
  await ref.read(dialoguesSettingProvider.notifier).loaded;
  if (!context.mounted) return;

  final request = await showSubtitleImportDialog(
    context,
    initial: ref.read(subtitleImportPrefsProvider),
    pickFile: pickFile,
    findByName: (context) => showSubtitleSearchDialog(context, service: ref.read(subtitleSearchServiceProvider)),
  );
  if (request == null || !context.mounted) return;

  // A picked file has no poster: look one up by its name meanwhile.
  final poster = request.imageUrl != null
      ? Future<String?>.value(request.imageUrl)
      : findSubtitlePoster(ref.read(subtitleSearchServiceProvider), subtitleFilmTitle(request));

  await prefsNotifier.recordUsed(level: request.level, maximum: request.maximum);
  if (!context.mounted) return;
  final startedIn = currentCollectionId();
  final prefs = ref.read(subtitleImportPrefsProvider);
  final withAi = prefs.translator != SubtitleTranslator.google;
  final withDialogues = withAi && ref.read(dialoguesSettingProvider);
  final stopwatch = Stopwatch();
  // The cue starts stay until the rows are built (word-context ADR-0003).
  var timedLines = const <({Duration start, String text})>[];
  var sentContexts = const <String, String>{};

  // The file (still downloading when found by name) is read and its words are
  // picked inside the progress dialog; the translation follows.
  final picking = request.bytes.then((bytes) {
    timedLines =
        SubtitleParser.parseTimed(utf8.decode(bytes, allowMalformed: true), extension: request.extension);
    final lines = [for (final line in timedLines) line.text];
    final picked = SubtitleWordCounter.pick(
      lines,
      maximum: request.maximum,
      level: request.level,
      collectionWords: collectionWords(),
      boostCloseRepeats: prefs.boostCloseRepeats,
      removeNames: prefs.removeNames,
    );
    if (picked.isEmpty) throw const _NoWords();
    sentContexts = picked.contexts;
    return picked;
  });

  SubtitleWordsResult? result;
  final translated = picking.then((picked) {
    stopwatch.start();
    return withAi
        ? ref
            .read(subtitleWordsServiceProvider)
            .pickWords(
              words: picked.words,
              contexts: picked.contexts,
              lines: picked.lines,
              maximum: request.maximum,
              model: prefs.modelInUse,
              collectionWords: collectionWords(),
              dialogues: withDialogues,
            )
            .then((r) => (result = r).words)
        : ref.read(subtitleGoogleWordsProvider).translate(picked.words, contexts: picked.contexts, maximum: request.maximum);
  }).whenComplete(stopwatch.stop);

  final outcome = await showSubtitleProgressDialog(
    context,
    fileName: request.fileName,
    title: request.title,
    imageUrl: request.imageUrl,
    picked: picking.then((p) => (words: p.words.take(request.maximum).toList(), contexts: p.contexts)),
    translated: translated,
  );
  if (!context.mounted) return;

  List<VocabWord> words;
  switch (outcome) {
    case SubtitleProgressCancelled():
      debugPrint('SUBTITLES: cancelled');
      return;
    case SubtitleProgressFailed(:final error):
      debugPrint('SUBTITLES: $error');
      final message = switch (error) {
        _NoWords() => SubtitleImportMessages.noEnglish,
        SubtitleSearchException(:final error) => SubtitleSearchMessages.of(error),
        SubtitleWordsException(:final error) => switch (error) {
            SubtitleWordsError.noEnglish => SubtitleImportMessages.noEnglish,
            SubtitleWordsError.tooManyImports => SubtitleImportMessages.tooManyImports,
            SubtitleWordsError.notPicked => SubtitleImportMessages.notPicked,
          },
        _ => SubtitleImportMessages.notPicked,
      };
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
      return;
    case SubtitleProgressDone(words: final done):
      words = done;
  }
  if (words.length > request.maximum) {
    // spec §6 "Word maximum respected": never show more than was asked for.
    debugPrint('SUBTITLES: ${words.length} words for a maximum of ${request.maximum}');
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text(SubtitleImportMessages.notPicked)));
    return;
  }
  final kept = await showSubtitleResultDialog(
    context,
    words,
    title: request.title,
    imageUrl: request.imageUrl,
    infoLine: result == null
        ? subtitleGoogleInfoLine(stopwatch.elapsed)
        : subtitleInfoLine(
            model: result!.model,
            elapsed: stopwatch.elapsed,
            inputTokens: result!.inputTokens,
            outputTokens: result!.outputTokens,
          ),
  );
  if (kept != null && kept.isNotEmpty && context.mounted) {
    final posterUrl = await poster.timeout(_posterWait, onTimeout: () => null);
    if (!context.mounted) return;
    final dialogues = result?.dialogues ?? const <ImportedDialogue>[];
    final origin = subtitleOrigin(request);
    WordPair filmRow(WordPair row) =>
        subtitleFilmRow(row, origin: origin, contexts: sentContexts, lines: timedLines);
    if (startedIn != null && currentCollectionId() != startedIn) {
      // Another collection was opened since Start: the result goes to the one
      // it started in (collections-screen ADR-0006, AC-11).
      await addWordsTo?.call(
          startedIn, kept, subtitleFilmTitle(request), posterUrl, withDialogues ? dialogues : const [], filmRow);
      return;
    }
    addWords(kept, subtitleFilmTitle(request), posterUrl, filmRow);
    if (withDialogues && dialogues.isNotEmpty) {
      addDialogues?.call(dialogues, kept.length);
    }
  }
}

/// The title the learner sees for the film or episode of [request] (spec
/// AC-22): the one found by name, else the picked file's name without its
/// extension.
String subtitleFilmTitle(SubtitleImportRequest request) {
  final title = request.title?.trim();
  if (title != null && title.isNotEmpty) return title;
  final name = request.fileName;
  final dot = name.lastIndexOf('.');
  final bare = (dot > 0 ? name.substring(0, dot) : name).trim();
  return bare.isEmpty ? name : bare;
}

/// Gives a row built from a kept subtitle word its film origin, time and
/// context (word-context AC-06 – AC-09); returns the same row.
typedef SubtitleFilmRow = WordPair Function(WordPair row);

/// The movie origin of every row of [request] (word-context AC-06, AC-07): a
/// file found by name keeps the picked result's series name (else its title),
/// season and episode; a file opened by the learner is named like its source
/// ([subtitleFilmTitle]) and takes the season and episode in its file name,
/// none when it has none. The time is set per row by [subtitleFilmRow].
WordOrigin subtitleOrigin(SubtitleImportRequest request) {
  final origin = WordOrigin()..typeOfSource = SourceType.movie;
  final found = request.found;
  if (found != null) {
    final show = found.show?.trim() ?? '';
    origin
      ..movieName = show.isNotEmpty ? show : found.title.trim()
      ..season = found.season
      ..episode = found.episode;
  } else {
    final mark = episodeFromFileName(request.fileName);
    origin
      ..movieName = subtitleFilmTitle(request)
      ..season = mark.season
      ..episode = mark.episode;
  }
  return origin;
}

/// [row] with a copy of [origin], the start of the first of [lines] that has
/// its word (word-context AC-08) and, as its `source` context, the passage
/// sent for that word in [contexts] (AC-09; none when there is none).
WordPair subtitleFilmRow(
  WordPair row, {
  required WordOrigin origin,
  required Map<String, String> contexts,
  required List<({Duration start, String text})> lines,
}) {
  final word = row.word.trim();
  var context = contexts[word] ?? contexts[word.toLowerCase()];
  if (context == null) {
    for (final entry in contexts.entries) {
      if (entry.key.toLowerCase() == word.toLowerCase()) {
        context = entry.value;
        break;
      }
    }
  }
  final trimmed = (context ?? '').trim();
  return row
    ..origin = (origin.copy()..time = firstLineTime(word, lines))
    ..context = trimmed
    ..contextKind = trimmed.isEmpty ? ContextKind.none : ContextKind.source;
}

/// How long Done waits for a poster still being looked up.
const _posterWait = Duration(seconds: 3);

/// The poster of the film or series named [title], from the subtitle search's
/// title suggestions: the first suggestion that has one. Null when nothing
/// is found or the search fails; never throws.
Future<String?> findSubtitlePoster(SubtitleSearchService service, String title) async {
  final query = subtitlePosterQuery(title);
  if (query.isEmpty) return null;
  try {
    final titles = await service.titles(query);
    for (final t in titles) {
      final url = t.imageUrl;
      if (url != null && url.isNotEmpty) return url;
    }
  } catch (e) {
    debugPrint('SUBTITLES: no poster for "$query": $e');
  }
  return null;
}

/// The film's name in a subtitle file's name: dots and underscores made
/// spaces, cut before an episode mark (S01E02), a year or a release tag, and
/// brackets dropped. "The.Office.S01E02.720p.srt" → "The Office".
String subtitlePosterQuery(String fileTitle) {
  var q = fileTitle.replaceAll(RegExp(r'[._]+'), ' ');
  q = q.replaceAll(RegExp(r'\[[^\]]*\]|\([^)]*\)'), ' ');
  final cut = RegExp(
    r'\b(s\d{1,2}\s?e\d{1,3}|\d{1,2}x\d{2}|(19|20)\d{2}|480p|720p|1080p|2160p|4k|web(-?dl|rip)?|bluray|brrip|hdtv|dvdrip|hdrip|x26[45]|h ?26[45]|hevc|yify)\b',
    caseSensitive: false,
  ).firstMatch(q);
  if (cut != null && cut.start > 0) q = q.substring(0, cut.start);
  return q.replaceAll(RegExp(r'\s+'), ' ').trim();
}

/// The file holds no word to propose: no English dialogue, or only words the
/// level already knows.
class _NoWords implements Exception {
  const _NoWords();
}
