/// The launch backfill of empty contexts (word-context AC-12, ADR-0004;
/// learn-welcome owner brief Q12): typed and set rows with a definition take
/// the define API's example of their sense, film rows the first stored
/// dialogue line that has the word, photo rows the sentence of their photo's
/// stored full text that has it. Photos are never analysed again and no AI
/// writes anything. At most [ContextBackfill.perMinute] words a minute.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';

import '../dialogues/dialogue_match.dart';
import '../models/definition_result.dart';
import '../models/film_dialogue.dart';
import '../models/session_source.dart';
import '../models/word_collection.dart';
import '../models/word_origin.dart';
import '../models/word_pair.dart';
import '../services/collection_store.dart';
import '../services/dictionary_service.dart';

/// What the backfill found for one row: [context] null when nothing was
/// found (the row is only marked tried). [word] and [definition] are what the
/// row held when it was looked at; a row changed since is left alone.
typedef ContextFill = ({
  String rowId,
  String word,
  String definition,
  String? context,
});

/// Whether [row] still waits for the backfill: a word, no context, never
/// tried (a changed word clears `contextTried`, `withChangedWord`).
bool needsContext(WordPair row) =>
    row.word.trim().isNotEmpty &&
    row.rowId.isNotEmpty &&
    row.context.trim().isEmpty &&
    !row.contextTried;

/// Applies [fills] to [words] in place: a row with the fill's id, still the
/// same word and definition, still empty and untried, takes the context (kind
/// source) and is marked tried. Returns whether anything changed.
bool applyContextFills(List<WordPair> words, List<ContextFill> fills) {
  final byId = {for (final f in fills) f.rowId: f};
  var changed = false;
  for (final w in words) {
    final f = byId[w.rowId];
    if (f == null || !needsContext(w)) continue;
    if (w.word != f.word || w.definition != f.definition) continue;
    final context = f.context;
    if (context != null) {
      w
        ..context = context
        ..contextKind = ContextKind.source;
    }
    w.contextTried = true;
    changed = true;
  }
  return changed;
}

/// The first stored dialogue line of [collection] that has [row]'s word as a
/// whole word: the dialogues linked to the row first, then the others, in
/// pager order. Null when none has it.
String? filmLineFor(WordPair row, List<FilmDialogue> dialogues) {
  final linked = [
    for (final d in dialogues)
      if (d.wordRowIds.contains(row.rowId)) d,
  ];
  final rest = [
    for (final d in dialogues)
      if (!d.wordRowIds.contains(row.rowId)) d,
  ];
  for (final d in [...linked, ...rest]) {
    for (final line in d.lines) {
      if (appears(line, row.word)) return line.trim();
    }
  }
  return null;
}

/// A sentence longer than this is OCR text without stops: the line that has
/// the word is used instead.
const _longSentence = 300;

final _sentenceEnd = RegExp(r'(?<=[.!?…])\s+');

/// The sentence of a photo's [fullText] that has [word] as a whole word, its
/// line breaks turned into spaces. Null when none has it.
String? photoSentenceFor(String word, String? fullText) {
  if (fullText == null || fullText.trim().isEmpty) return null;
  final flat = fullText.replaceAll(RegExp(r'\s+'), ' ').trim();
  for (final sentence in flat.split(_sentenceEnd)) {
    if (!appears(sentence, word)) continue;
    if (sentence.length <= _longSentence) return sentence.trim();
    for (final line in fullText.split('\n')) {
      if (appears(line, word)) return line.trim();
    }
    return sentence.trim();
  }
  return null;
}

String _definitionLine(String stored) {
  final lines = [for (final l in stored.split('\n')) l.trim()];
  for (final l in lines) {
    if (l.toLowerCase().startsWith('definition:')) {
      return l.substring('definition:'.length).trim();
    }
  }
  for (final l in lines) {
    if (l.isNotEmpty && !l.toLowerCase().startsWith('example:')) return l;
  }
  return '';
}

String _norm(String s) =>
    _definitionLine(s).toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

/// The example of the sense matching [definition] (the same text, or the same
/// definition line), else the first example any sense has. Null when no
/// sense has one.
String? exampleForDefinition(List<String> senses, String definition) {
  final want = _norm(definition);
  for (final s in senses) {
    if (s.trim() == definition.trim() || (want.isNotEmpty && _norm(s) == want)) {
      final example = DefinitionResult.exampleOfSense(s);
      if (example != null) return example;
      break;
    }
  }
  for (final s in senses) {
    final example = DefinitionResult.exampleOfSense(s);
    if (example != null) return example;
  }
  return null;
}

/// Walks every collection outside the bin, newest first, and fills empty
/// contexts (see the library doc). One [CollectionStore.update] per
/// collection batch; every row looked at is marked tried, found or not. A
/// dictionary that is unavailable (offline, Worker down) leaves its rows
/// untried for the next launch and is not asked again in this run. Never
/// throws.
class ContextBackfill {
  /// AC-12 / Q12: at most this many words a minute.
  static const perMinute = 20;

  final Future<CollectionStore> Function() _store;
  final DictionaryService _dictionary;
  final DateTime Function() _now;
  final Future<void> Function(Duration) _sleep;

  ContextBackfill({
    required Future<CollectionStore> Function() store,
    required DictionaryService dictionary,
    DateTime Function()? now,
    Future<void> Function(Duration)? sleep,
  })  : _store = store,
        _dictionary = dictionary,
        _now = now ?? DateTime.now,
        _sleep = sleep ?? Future<void>.delayed;

  Future<void>? _running;
  bool _cancelled = false;

  /// Stops the run before its next read or write (the provider calls it when
  /// it goes, so nothing touches a store that is closing).
  void cancel() => _cancelled = true;

  /// Starts the backfill once; later calls return the same run. [onWritten]
  /// hears every batch written, so the screen's copy of a collection can
  /// take the same contexts.
  Future<void> start(
      {void Function(String collectionId, List<ContextFill> fills)?
          onWritten}) =>
      _running ??= run(onWritten: onWritten);

  DateTime? _windowStart;
  int _used = 0;

  /// Waits, when this minute's words are used up, for the next minute.
  Future<void> _takeOne() async {
    final now = _now();
    final start = _windowStart;
    if (start == null || now.difference(start) >= const Duration(minutes: 1)) {
      _windowStart = now;
      _used = 0;
    } else if (_used >= perMinute) {
      final wait = start.add(const Duration(minutes: 1)).difference(now);
      if (wait > Duration.zero) await _sleep(wait);
      _windowStart = _now();
      _used = 0;
    }
    _used++;
  }

  Future<void> run(
      {void Function(String collectionId, List<ContextFill> fills)?
          onWritten}) async {
    try {
      if (_cancelled) return;
      final store = await _store();
      var dictionaryDown = false;
      var looked = 0, found = 0;
      if (_cancelled) return;
      for (final c in await store.nonEmpty()) {
        if (_cancelled) return;
        if (await store.isBinned(c)) continue;
        final batch = <ContextFill>[];
        Future<void> write() async {
          if (batch.isEmpty || _cancelled) return;
          final fills = [...batch];
          batch.clear();
          final ok = await store.update(
              c.collectionId, (s) => applyContextFills(s.words, fills));
          if (ok) onWritten?.call(c.collectionId, fills);
        }

        for (final row in [...c.words]) {
          if (!needsContext(row)) continue;
          final kind = _kindOf(row, c);
          if (kind == null) {
            batch.add(_fill(row, null));
            continue;
          }
          if (kind == _Kind.dictionary && dictionaryDown) continue;
          if (_used >= perMinute && _windowStart != null) {
            // Write what this minute found before waiting for the next one.
            await write();
          }
          await _takeOne();
          if (_cancelled) return;
          looked++;
          String? context;
          switch (kind) {
            case _Kind.dictionary:
              final stored =
                  DefinitionResult.decodeSenses(row.definitionOptionsJson);
              if (stored.isNotEmpty) {
                context = exampleForDefinition(stored, row.definition);
              } else {
                final result = await _dictionary.define(row.word);
                if (_cancelled) return;
                if (result.kind == DefinitionKind.unavailable) {
                  dictionaryDown = true;
                  continue;
                }
                context = exampleForDefinition(result.senses, row.definition);
              }
            case _Kind.film:
              context = filmLineFor(row, c.dialogues);
            case _Kind.photo:
              context = photoSentenceFor(row.word, _photoText(row, c.sources));
          }
          if (context != null) found++;
          batch.add(_fill(row, context));
        }
        await write();
      }
      debugPrint('VOCAB: context backfill: $looked looked up, $found found');
    } catch (e) {
      debugPrint('VOCAB: context backfill failed: $e');
    }
  }

  static ContextFill _fill(WordPair row, String? context) => (
        rowId: row.rowId,
        word: row.word,
        definition: row.definition,
        context: context,
      );

  /// Where [row]'s context can come from; null when there is nowhere to look
  /// (a typed row with a translation only, a film or photo with nothing
  /// stored): the row is just marked tried, which costs no word of the
  /// minute.
  static _Kind? _kindOf(WordPair row, WordCollection c) {
    switch (row.origin.typeOfSource) {
      case SourceType.manuallyEntered:
      case SourceType.set:
        return row.definition.trim().isEmpty ? null : _Kind.dictionary;
      case SourceType.movie:
        return c.dialogues.any((d) => d.lines.isNotEmpty) ? _Kind.film : null;
      case SourceType.image:
        final text = _photoText(row, c.sources);
        return text == null || text.trim().isEmpty ? null : _Kind.photo;
    }
  }

  static String? _photoText(WordPair row, List<SessionSource> sources) {
    for (final s in sources) {
      if (s.id == row.sourceId && s.kind == SourceKind.photo) {
        return s.fullText;
      }
    }
    return null;
  }
}

enum _Kind { dictionary, film, photo }
