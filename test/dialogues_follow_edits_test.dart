import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_vocabulary_app/core/models/film_dialogue.dart';
import 'package:flutter_vocabulary_app/core/models/session.dart';
import 'package:flutter_vocabulary_app/core/models/word_pair.dart';
import 'package:flutter_vocabulary_app/core/providers.dart';
import 'package:flutter_vocabulary_app/core/services/session_store.dart';
import 'package:flutter_vocabulary_app/features/word_input/word_input_notifier.dart';

/// get-words-from-subtitles-improvment T18: a dialogue follows its words
/// through every edit, in the same save (AC-11, AC-26).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    final saved = HttpOverrides.current;
    HttpOverrides.global = null;
    try {
      await Isar.initializeIsarCore(download: true);
    } finally {
      HttpOverrides.global = saved;
    }
  });

  late Directory dir;
  late SessionStore store;
  late ProviderContainer container;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    dir = Directory.systemTemp.createTempSync('dialogues_follow_edits_test');
    store = await SessionStore.open(directory: dir.path);
    container = ProviderContainer(
        overrides: [sessionStoreProvider.overrideWith((ref) async => store)]);
  });

  tearDown(() async {
    container.dispose();
    await store.close();
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });

  WordPair pair(String id, String word) =>
      WordPair(word: word, translation: 'т-$word', rowId: id);

  /// A current session with rows attic (r1), stairs (r2), fog (r3) and one
  /// dialogue holding attic and stairs.
  Future<(WordInputNotifier, String)> current(
      {PushState push = PushState.none}) async {
    final s = Session.create()
      ..words = [pair('r1', 'attic'), pair('r2', 'stairs'), pair('r3', 'fog')]
      ..dialogues = [
        FilmDialogue()
          ..id = 'd1'
          ..lines = ['- The attic?', '- Up the stairs.']
          ..wordRowIds = ['r1', 'r2']
          ..pushState = push,
      ]
      ..lastLocalModifiedAt = DateTime.now();
    await store.put(s);
    await store.setCurrentSessionId(s.sessionId);
    await container.read(wordInputNotifierProvider.future);
    return (container.read(wordInputNotifierProvider.notifier), s.sessionId);
  }

  Future<List<FilmDialogue>> saved(WordInputNotifier n, String id) async {
    await n.flush();
    return (await store.byId(id))!.dialogues;
  }

  test('deleting a dialogue word drops it (AC-11)', () async {
    final (n, id) = await current();
    n.removeAt(0);
    expect((await saved(n, id)).single.wordRowIds, ['r2']);
  });

  test('editing its translation keeps it, row id and all (AC-11)', () async {
    final (n, id) = await current();
    n.updateAt(0, translation: 'горище');
    final session = (await store.byId(id))!;
    await n.flush();
    final after = (await store.byId(id))!;
    expect(after.words.first.rowId, 'r1');
    expect(after.dialogues.single.wordRowIds, ['r1', 'r2']);
    expect(session.dialogues.single.wordRowIds, ['r1', 'r2']);
  });

  test('editing its word to a form still in the text keeps it', () async {
    final (n, id) = await current();
    n.updateAt(1, word: 'stair');
    expect((await saved(n, id)).single.wordRowIds, ['r1', 'r2']);
  });

  test('editing its word out of the text drops it (AC-11)', () async {
    final (n, id) = await current();
    n.updateAt(1, word: 'cellar');
    expect((await saved(n, id)).single.wordRowIds, ['r1']);
  });

  test('deleting every dialogue word removes the dialogue (AC-26)', () async {
    final (n, id) = await current();
    n.removeAt(0);
    n.removeAt(0);
    expect(await saved(n, id), isEmpty);
  });

  test('a pending dialogue left without words is hidden (ADR-0005)', () async {
    final (n, id) = await current(push: PushState.pending);
    n.removeAt(0);
    n.removeAt(0);
    final d = (await saved(n, id)).single;
    expect(d.hidden, isTrue);
    expect(d.wordRowIds, isEmpty);
  });

  test('a word typed in again or added never joins (AC-11)', () async {
    final (n, id) = await current();
    n.removeAt(0);
    n.addAll([WordPair(word: 'attic', translation: 'т')]);
    n.setPairs([
      ...container.read(wordInputNotifierProvider).value!.words,
      WordPair(word: 'stairs', translation: 'т'),
    ]);
    expect((await saved(n, id)).single.wordRowIds, ['r2']);
  });

  test('reordering keeps every link', () async {
    final (n, id) = await current();
    n.reorder(0, 2);
    expect((await saved(n, id)).single.wordRowIds, ['r1', 'r2']);
  });

  test('replacing the rows with setPairs follows them too', () async {
    final (n, id) = await current();
    n.setPairs([pair('r2', 'stairs')]);
    expect((await saved(n, id)).single.wordRowIds, ['r2']);
  });
}
