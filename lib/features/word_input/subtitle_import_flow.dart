import 'dart:convert';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/vocab_word.dart';
import '../../core/providers.dart';
import '../../core/services/subtitle_parser.dart';
import '../../core/services/subtitle_words_service.dart';
import 'widgets/import_loading_dialog.dart';
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
/// Settings while "Update with each import" is on — the non-dismissible
/// loading dialog while the file is read and the Worker picks the words, then
/// the results dialog. Only Done changes the session, through [addWords];
/// every failure closes the loading dialog with its message and leaves the
/// session as it was. A result for a session other than the one current at
/// Start is dropped (AC-16).
Future<void> runSubtitleImport({
  required BuildContext context,
  required WidgetRef ref,
  required String? Function() currentSessionId,
  required List<String> Function() sessionWords,
  required void Function(List<VocabWord> words) addWords,
  Future<XFile?> Function()? pickFile,
}) async {
  final prefsNotifier = ref.read(subtitleImportPrefsProvider.notifier);
  await prefsNotifier.loaded;
  if (!context.mounted) return;

  final request = await showSubtitleImportDialog(
    context,
    initial: ref.read(subtitleImportPrefsProvider),
    pickFile: pickFile,
  );
  if (request == null || !context.mounted) return;

  await prefsNotifier.recordUsed(purpose: request.purpose, level: request.level, maximum: request.maximum);
  if (!context.mounted) return;
  final startedIn = currentSessionId();
  final model = ref.read(subtitleImportPrefsProvider).model;
  final stopwatch = Stopwatch()..start();
  showImportLoadingDialog(context);

  SubtitleWordsResult? result;
  String? message;
  try {
    final lines = SubtitleParser.parse(
      utf8.decode(request.bytes, allowMalformed: true),
      extension: request.extension,
    );
    if (lines.isEmpty) {
      message = SubtitleImportMessages.noEnglish;
    } else {
      result = await ref.read(subtitleWordsServiceProvider).pickWords(
            lines: lines,
            purpose: request.purpose,
            level: request.level,
            maximum: request.maximum,
            model: model,
            sessionWords: sessionWords(),
          );
      if (result.words.length > request.maximum) {
        // spec §6 "Word maximum respected": never show more than was asked for.
        debugPrint('SUBTITLES: ${result.words.length} words for a maximum of ${request.maximum}');
        result = null;
        message = SubtitleImportMessages.notPicked;
      }
    }
  } on SubtitleWordsException catch (e) {
    debugPrint('SUBTITLES: $e');
    message = switch (e.error) {
      SubtitleWordsError.noEnglish => SubtitleImportMessages.noEnglish,
      SubtitleWordsError.tooManyImports => SubtitleImportMessages.tooManyImports,
      SubtitleWordsError.notPicked => SubtitleImportMessages.notPicked,
    };
  } catch (e) {
    debugPrint('SUBTITLES: import failed: $e');
    message = SubtitleImportMessages.notPicked;
  }
  stopwatch.stop();
  if (!context.mounted) return;
  closeImportLoadingDialog(context);

  if (message != null) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    return;
  }
  if (currentSessionId() != startedIn) {
    debugPrint('SUBTITLES: the session changed during the import; words dropped');
    return;
  }

  final kept = await showSubtitleResultDialog(
    context,
    result!.words,
    infoLine: subtitleInfoLine(
      model: result.model,
      elapsed: stopwatch.elapsed,
      inputTokens: result.inputTokens,
      outputTokens: result.outputTokens,
    ),
  );
  if (kept != null && kept.isNotEmpty && context.mounted && currentSessionId() == startedIn) {
    addWords(kept);
  }
}
