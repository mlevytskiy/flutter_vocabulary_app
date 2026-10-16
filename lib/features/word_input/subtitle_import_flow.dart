import 'dart:convert';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/dialogues/dialogue_rules.dart' show ImportedDialogue;
import '../../core/models/vocab_word.dart';
import '../../core/providers.dart';
import '../../core/models/subtitle_import_options.dart';
import '../../core/services/subtitle_parser.dart';
import '../../core/services/subtitle_search_service.dart';
import '../../core/services/subtitle_word_counter.dart';
import '../../core/services/subtitle_words_service.dart';
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
/// session as it was. A result for a session other than the one current at
/// Start is dropped (AC-16). With the AI translating and "Get dialogues from
/// subtitles" on, the import also asks for film dialogues; they ride with the result, unseen by
/// the results dialog, and right after [addWords] go to [addDialogues] with
/// the number of words kept, so one save holds both
/// (get-words-from-subtitles-improvment AC-02, AC-03). [addWords] also gets
/// the film's title ([subtitleFilmTitle]), the source the screen records the
/// kept rows under (side-panel-sources, spec AC-22), and its poster's address
/// for the photo panel's tile (owner, 2026-10-15): the one found by name, or,
/// for a picked file, one looked up by the file's name while the dialogs are
/// open ([findSubtitlePoster]); null when none is found in time.
Future<void> runSubtitleImport({
  required BuildContext context,
  required WidgetRef ref,
  required String? Function() currentSessionId,
  required List<String> Function() sessionWords,
  required void Function(List<VocabWord> words, String film, String? poster) addWords,
  void Function(List<ImportedDialogue> dialogues, int keptCount)? addDialogues,
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
  final startedIn = currentSessionId();
  final prefs = ref.read(subtitleImportPrefsProvider);
  final withAi = prefs.translator != SubtitleTranslator.google;
  final withDialogues = withAi && ref.read(dialoguesSettingProvider);
  final stopwatch = Stopwatch();

  // The file (still downloading when found by name) is read and its words are
  // picked inside the progress dialog; the translation follows.
  final picking = request.bytes.then((bytes) {
    final lines = SubtitleParser.parse(utf8.decode(bytes, allowMalformed: true), extension: request.extension);
    final picked = SubtitleWordCounter.pick(
      lines,
      maximum: request.maximum,
      level: request.level,
      sessionWords: sessionWords(),
      boostCloseRepeats: prefs.boostCloseRepeats,
      removeNames: prefs.removeNames,
    );
    if (picked.isEmpty) throw const _NoWords();
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
              sessionWords: sessionWords(),
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
  if (currentSessionId() != startedIn) {
    debugPrint('SUBTITLES: the session changed during the import; words dropped');
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
  if (kept != null && kept.isNotEmpty && context.mounted && currentSessionId() == startedIn) {
    final posterUrl = await poster.timeout(_posterWait, onTimeout: () => null);
    if (!context.mounted || currentSessionId() != startedIn) return;
    addWords(kept, subtitleFilmTitle(request), posterUrl);
    final dialogues = result?.dialogues ?? const [];
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
