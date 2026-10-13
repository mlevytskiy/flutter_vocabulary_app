import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_vocabulary_app/core/dialogues/dialogue_rules.dart';
import 'package:flutter_vocabulary_app/core/models/film_dialogue.dart';
import 'package:flutter_vocabulary_app/core/models/session.dart';
import 'package:flutter_vocabulary_app/core/models/word_pair.dart';

/// get-words-from-subtitles-improvment T14: which rows a dialogue holds at
/// Done and after edits, and the names of the dialogue group cards.
void main() {
  WordPair row(String id, String word, [String translation = 'т']) =>
      WordPair(word: word, translation: translation, rowId: id);

  FilmDialogue dialogue(String id, List<String> lines, List<String> rowIds) =>
      FilmDialogue()
        ..id = id
        ..lines = lines
        ..wordRowIds = rowIds;

  group('atDone (AC-03)', () {
    var n = 0;
    String newId() => 'id-${++n}';
    setUp(() => n = 0);

    test('links each dialogue to the kept rows of its words', () {
      final kept = [row('r1', 'attic'), row('r2', 'reluctant')];
      final out = atDone([
        (lines: ['- Where is it?', '- In the Attic.'], words: ['attic']),
        (lines: ['I was reluctant to go.'], words: ['Reluctant']),
      ], kept, newId: newId);
      expect(out.map((d) => d.wordRowIds), [
        ['r1'],
        ['r2'],
      ]);
      expect(out.map((d) => d.id), ['id-1', 'id-2']);
      expect(out.first.lines, ['- Where is it?', '- In the Attic.']);
    });

    test('drops removed words and dialogues left with none', () {
      // 3 dialogues; the learner removed "attic" and "stairs", every word of
      // the first one, and "loft" from the second.
      final kept = [row('r3', 'dusty'), row('r4', 'reluctant')];
      final out = atDone([
        (lines: ['The attic stairs.'], words: ['attic', 'stairs']),
        (lines: ['A dusty loft.'], words: ['dusty', 'loft']),
        (lines: ['So reluctant.'], words: ['reluctant']),
      ], kept, newId: newId);
      expect(out, hasLength(2));
      expect(out[0].lines, ['A dusty loft.']);
      expect(out[0].wordRowIds, ['r3']);
      expect(out[1].wordRowIds, ['r4']);
    });

    test('a word in two dialogues is linked to both (AC-06)', () {
      final kept = [row('r1', 'reluctant')];
      final out = atDone([
        (lines: ['So reluctant.'], words: ['reluctant']),
        (lines: ['Reluctant again.'], words: ['reluctant']),
      ], kept, newId: newId);
      expect(out.map((d) => d.wordRowIds), [
        ['r1'],
        ['r1'],
      ]);
    });

    test('a linked word that does not appear in the lines is not linked', () {
      final out = atDone([
        (lines: ['Nothing here.'], words: ['attic']),
      ], [
        row('r1', 'attic')
      ], newId: newId);
      expect(out, isEmpty);
    });

    test('new dialogues have nothing to deliver and are not hidden', () {
      final out = atDone([
        (lines: ['attic'], words: ['attic']),
      ], [
        row('r1', 'attic')
      ], newId: newId);
      expect(out.single.pushState, PushState.none);
      expect(out.single.hidden, isFalse);
      expect(out.single.importId, isNull);
    });
  });

  group('afterEdit (AC-11, AC-26)', () {
    Session session(List<WordPair> words, List<FilmDialogue> dialogues) =>
        Session.create()
          ..words = words
          ..dialogues = dialogues;

    test('a deleted row leaves the dialogue', () {
      final s = session([
        row('r1', 'attic')
      ], [
        dialogue('d1', ['The attic and the stairs.'], ['r1', 'r2']),
      ]);
      expect(afterEdit(s).single.wordRowIds, ['r1']);
    });

    test('an edited word stays only where its new form still appears', () {
      final s = session([
        row('r1', 'stair'),
        row('r2', 'cellar')
      ], [
        dialogue('d1', ['The attic', 'and the stairs.'], ['r1', 'r2']),
      ]);
      // "stair" + "s" still appears (on the second line); "cellar" does not.
      expect(afterEdit(s).single.wordRowIds, ['r1']);
    });

    test('an edited translation keeps the link', () {
      final s = session([
        row('r1', 'attic', 'мансарда')
      ], [
        dialogue('d1', ['The attic.'], ['r1']),
      ]);
      expect(afterEdit(s).single.wordRowIds, ['r1']);
    });

    test('a dialogue with no words left disappears', () {
      final s = session([
        row('r1', 'cellar')
      ], [
        dialogue('d1', ['The attic.'], ['r1']),
        dialogue('d2', ['The cellar.'], ['r1']),
      ]);
      expect(afterEdit(s).map((d) => d.id), ['d2']);
    });

    test('a pending dialogue with no words left is hidden, not removed', () {
      final s = session([], [
        dialogue('d1', ['The attic.'], ['r1'])..pushState = PushState.pending,
      ]);
      final out = afterEdit(s).single;
      expect(out.hidden, isTrue);
      expect(out.wordRowIds, isEmpty);
    });

    test('links only shrink: a re-typed or new row never joins', () {
      // r1 was deleted and "attic" typed in again as r9.
      final s = session([
        row('r9', 'attic'),
        row('r2', 'stairs')
      ], [
        dialogue('d1', ['The attic stairs.'], ['r1', 'r2']),
      ]);
      expect(afterEdit(s).single.wordRowIds, ['r2']);
    });

    test('a blank row does not keep a link', () {
      final s = session([
        WordPair(word: '', translation: '', rowId: 'r1')
      ], [
        dialogue('d1', ['The attic.'], ['r1']),
      ]);
      expect(afterEdit(s), isEmpty);
    });

    test('does not change the session it reads', () {
      final d = dialogue('d1', ['The attic.'], ['r1', 'r2']);
      afterEdit(session([row('r1', 'attic')], [d]));
      expect(d.wordRowIds, ['r1', 'r2']);
    });
  });

  group('cardName (AC-13)', () {
    test('the first line without speaker marks', () {
      final d = dialogue('d1', ['- JOHN: Where is it?', 'In the attic.'], []);
      expect(cardName(d, [d]), 'Where is it?');
      final e = dialogue('d2', ['A: Fine.'], []);
      expect(cardName(e, [e]), 'Fine.');
      final f = dialogue('d3', ['— Fine, thanks.'], []);
      expect(cardName(f, [f]), 'Fine, thanks.');
    });

    test('cut to 40 characters with "…"', () {
      final d = dialogue('d1', ['A' * 50], []);
      expect(cardName(d, [d]), '${'A' * 40}…');
      final e = dialogue('d2', ['A' * 40], []);
      expect(cardName(e, [e]), 'A' * 40);
    });

    test('"(2)", "(3)" when names repeat, in pager order', () {
      final a = dialogue('d1', ['- What?'], []);
      final b = dialogue('d2', ['Fine.'], []);
      final c = dialogue('d3', ['B: What?'], []);
      final d = dialogue('d4', ['What?'], []);
      final all = [a, b, c, d];
      expect(all.map((x) => cardName(x, all)),
          ['What?', 'Fine.', 'What? (2)', 'What? (3)']);
    });
  });
}
