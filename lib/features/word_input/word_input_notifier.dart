import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/models/word_pair.dart';
import '../../core/providers.dart';

part 'word_input_notifier.g.dart';

/// Owns the persisted word list. `WordInputScreen` keeps mirroring this into
/// its own `_wordPairs` field (controllers, focus nodes and the rest of its
/// per-row state stay keyed off that field, unchanged) and pushes every
/// mutation here right after making it, so this notifier is always a beat
/// behind the screen, never the other way around -- except once, on first
/// load, when the screen pulls the persisted list in to restore it.
@Riverpod(keepAlive: true)
class WordInputNotifier extends _$WordInputNotifier {
  Timer? _saveTimer;

  @override
  Future<List<WordPair>> build() async {
    ref.onDispose(() => _saveTimer?.cancel());
    return ref.read(wordStoreProvider).load();
  }

  List<WordPair> get _pairs => state.value ?? const [];

  void setPairs(List<WordPair> pairs) {
    state = AsyncData(List.of(pairs));
    _scheduleSave();
  }

  void updateAt(int i, {String? word, String? translation}) {
    final pairs = List<WordPair>.of(_pairs);
    if (i < 0 || i >= pairs.length) return;
    final current = pairs[i];
    pairs[i] = WordPair(
      word: word ?? current.word,
      translation: translation ?? current.translation,
    );
    state = AsyncData(pairs);
    _scheduleSave();
  }

  void removeAt(int i) {
    final pairs = List<WordPair>.of(_pairs);
    if (i < 0 || i >= pairs.length) return;
    pairs.removeAt(i);
    state = AsyncData(pairs);
    _scheduleSave();
  }

  void reorder(int oldIndex, int newIndex) {
    final pairs = List<WordPair>.of(_pairs);
    if (oldIndex < 0 || oldIndex >= pairs.length) return;
    final pair = pairs.removeAt(oldIndex);
    pairs.insert(newIndex.clamp(0, pairs.length), pair);
    state = AsyncData(pairs);
    _scheduleSave();
  }

  void addAll(List<WordPair> newPairs) {
    if (newPairs.isEmpty) return;
    final pairs = List<WordPair>.of(_pairs)..addAll(newPairs);
    state = AsyncData(pairs);
    _scheduleSave();
  }

  /// Cancels any pending debounced save and writes immediately. Blank pairs
  /// (the trailing empty row) are never persisted -- reload re-creates
  /// exactly one via `_checkAndAddNewPair`.
  Future<void> flush() async {
    _saveTimer?.cancel();
    await ref.read(wordStoreProvider).save(_pairs.where((p) => !p.isEmpty).toList());
  }

  void _scheduleSave() {
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 500), flush);
  }
}
