import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_vocabulary_app/core/models/subtitle_import_options.dart';
import 'package:flutter_vocabulary_app/core/services/subtitle_ignored_words.dart';
import 'package:flutter_vocabulary_app/core/services/subtitle_word_counter.dart';

/// The phone's frequency pick for a subtitle import: the most frequent words
/// without the 200 ignored ones, and only the lines around their places.
void main() {
  test('the common-word list: 8000 distinct lower-case words, commonest first', () {
    expect(subtitleCommonWords, hasLength(8000));
    expect(subtitleCommonWords.toSet(), hasLength(8000));
    expect(subtitleCommonWords.every((w) => RegExp(r'^[a-z]+$').hasMatch(w)), isTrue);
    expect(subtitleCommonWords.take(200), containsAll(['i', 'me', 'like', 'the', 'yeah']));
  });

  test('each level skips its own number of common words', () {
    expect({for (final l in EnglishLevel.values) l: subtitleIgnoredWordsFor(l).length}, {
      EnglishLevel.a1: 1000,
      EnglishLevel.a2: 1000,
      EnglishLevel.b1: 2000,
      EnglishLevel.b2: 4000,
      EnglishLevel.c1: 6000,
      EnglishLevel.c2: 8000,
    });
    expect(subtitleIgnoredWordsFor(EnglishLevel.b1), containsAll(['father', 'home', 'show']));
  });

  test('a word the level does not know yet is proposed; one it knows is not', () {
    final b1Word = subtitleCommonWords[1500];
    final c2Word = subtitleCommonWords[7000];
    List<String> words(EnglishLevel level) =>
        SubtitleWordCounter.pick(['$b1Word and $c2Word.'], maximum: 10, level: level).words;
    expect(words(EnglishLevel.a2), [b1Word, c2Word]);
    expect(words(EnglishLevel.b1), [c2Word]);
    expect(words(EnglishLevel.c1), [c2Word]);
    expect(words(EnglishLevel.c2), isEmpty);
  });

  test('most frequent first; ties keep the order of first use; ignored words never count', () {
    final pick = SubtitleWordCounter.pick([
      'I like the harbour.',
      'The fog is over the harbour.',
      'Me? I like fog and the harbour.',
      'Ships.',
    ], maximum: 10, level: EnglishLevel.b1);
    expect(pick.words, ['harbour', 'fog', 'ships']);
  });

  test('takes the maximum plus the extra candidates', () {
    final lines = [for (var i = 0; i < 40; i++) 'word${String.fromCharCode(97 + i % 26)}${String.fromCharCode(97 + i ~/ 26)}'];
    expect(SubtitleWordCounter.pick(lines, maximum: 5, level: EnglishLevel.b1).words, hasLength(5 + SubtitleWordCounter.extraCandidates));
  });

  test('session words are skipped in any letter case', () {
    final pick = SubtitleWordCounter.pick(['Tide and fog.', 'The tide.'], maximum: 10, level: EnglishLevel.b1, sessionWords: [' TIDE ']);
    expect(pick.words, ['fog']);
  });

  test('contractions lose their ending, and plurals join their singular', () {
    final pick = SubtitleWordCounter.pick([
      "Don't open the hatches.",
      "That hatch's jammed, can't you see?",
      'One hatch. Two fables, one fable.',
      "Mortimer's crates, a crate.",
    ], maximum: 10, level: EnglishLevel.b1);
    expect(pick.words, containsAllInOrder(['hatch', 'fable', 'crate']));
    expect(pick.words, isNot(contains('hatches')));
    expect(pick.words, isNot(contains('don')));
    expect(pick.words, isNot(contains('ca')));
  });

  test('a word only ever capitalised inside a sentence is taken for a name', () {
    final pick = SubtitleWordCounter.pick([
      'Call Mortimer, Mortimer knows.',
      'Hush, the drizzle.',
      'Hush.',
      'The drizzle stopped.',
    ], maximum: 10, level: EnglishLevel.b1);
    expect(pick.words, isNot(contains('mortimer')));
    expect(pick.words, contains('hush'), reason: 'capitalised only at a sentence start');
  });

  test('single letters, digits and non-Latin text are not words', () {
    final pick = SubtitleWordCounter.pick(['x 42 b', 'Привіт, світе'], maximum: 10, level: EnglishLevel.b1);
    expect(pick.isEmpty, isTrue);
  });

  test('only the lines around the first and last place are sent, with a gap between excerpts', () {
    final lines = [for (var i = 0; i < 20; i++) 'Okay $i.'];
    lines[2] = 'the lighthouse';
    lines[9] = 'the lighthouse again';
    lines[17] = 'the lighthouse at last';
    final pick = SubtitleWordCounter.pick(lines, maximum: 1, level: EnglishLevel.b1);
    expect(pick.words.first, 'lighthouse');
    final rest = pick.words.skip(1).toSet();
    expect(rest, isEmpty, reason: 'every other word is on the ignore list');
    expect(pick.lines, isNot(contains('the lighthouse again')), reason: 'only the first and last place');
    expect(pick.lines, contains('the lighthouse'));
    expect(pick.lines, contains('the lighthouse at last'));
    expect(pick.lines.length, lessThan(lines.length));
    expect(pick.lines, contains(SubtitleWordCounter.gap));
  });

  test('neighbouring places share their lines, without a gap', () {
    final pick = SubtitleWordCounter.pick(['A gale.', 'Vast gale.', 'Enormous gale.'], maximum: 1, level: EnglishLevel.b1);
    expect(pick.lines, ['A gale.', 'Vast gale.', 'Enormous gale.']);
  });

  test('each word\'s context is its line with one line on each side; the line is the first that reads like a sentence, else the longest', () {
    final pick = SubtitleWordCounter.pick([
      'Fog!',
      'The fog rolls over the bay.',
      'Fog again tonight.',
      'Hush.',
      'Hush now.',
    ], maximum: 10, level: EnglishLevel.a1);
    expect(pick.contexts['fog'], 'Fog! The fog rolls over the bay. Fog again tonight.');
    expect(pick.contexts['hush'], 'Hush. Hush now.', reason: 'the last line has nothing after it');
    expect(pick.contexts.keys, pick.words);
  });

  group('close repeats: a word the film keeps using in one scene ranks higher', () {
    test('the score is the uses plus 3 for each use within 2 lines of the one before', () {
      expect(SubtitleWordCounter.score([7]), 1);
      expect(SubtitleWordCounter.score([3, 4, 20]), 3 + 3);
      expect(SubtitleWordCounter.score([3, 5]), 2 + 3, reason: '2 lines apart is still close');
      expect(SubtitleWordCounter.score([3, 6]), 2, reason: '3 lines apart is not');
      expect(SubtitleWordCounter.score([4, 4]), 2 + 3, reason: 'twice in one line is close');
      expect(SubtitleWordCounter.score([1, 2, 3, 30, 31]), 5 + 3 * 3);
    });

    test('a word used 3 times in one scene beats one used 4 times far apart', () {
      final lines = [for (var i = 0; i < 40; i++) 'Okay.'];
      lines[0] = 'The lantern.';
      lines[10] = 'The lantern.';
      lines[20] = 'The lantern.';
      lines[30] = 'The lantern.';
      lines[34] = 'The harpoon.';
      lines[35] = 'A harpoon!';
      lines[37] = 'Drop the harpoon.';
      final pick = SubtitleWordCounter.pick(lines, maximum: 1, level: EnglishLevel.b1);
      // harpoon: 3 uses + 2 close repeats x 3 = 9; lantern: 4 uses, none close = 4.
      expect(pick.words.take(2), ['harpoon', 'lantern']);
      final plain = SubtitleWordCounter.pick(lines, maximum: 1, level: EnglishLevel.b1, boostCloseRepeats: false);
      expect(plain.words.take(2), ['lantern', 'harpoon'], reason: 'off: how often alone');
    });

    test('off, the score is the number of uses', () {
      expect(SubtitleWordCounter.score([1, 2, 3, 30, 31], boostCloseRepeats: false), 5);
    });

    test('a plural used next to its singular is a close repeat of it', () {
      final pick = SubtitleWordCounter.pick(
        ['A lantern.', 'Two lanterns.', 'Okay.', 'Okay.', 'Okay.', 'The harpoon.', 'Okay.', 'Okay.', 'Okay.', 'The harpoon.', 'Okay.', 'Okay.', 'Okay.', 'The harpoon.'],
        maximum: 1,
        level: EnglishLevel.b1,
      );
      // lantern: 2 uses + 1 close repeat = 5; harpoon: 3 uses, none close = 3.
      expect(pick.words.take(2), ['lantern', 'harpoon']);
    });
  });

  group('remove names', () {
    test('a name is never in lower case and has a capital inside a sentence, or is used twice, capitalised, and not common', () {
      bool name({bool inside = false, bool lower = false, int uses = 1, bool common = false}) =>
          SubtitleWordCounter.looksLikeName(capitalInside: inside, lowerSeen: lower, uses: uses, common: common);
      expect(name(inside: true), isTrue, reason: '"Call Mortimer now"');
      expect(name(uses: 2), isTrue, reason: '"Mortimer!" twice at line starts');
      expect(name(uses: 1), isFalse, reason: 'once at a sentence start: no evidence');
      expect(name(uses: 3, common: true), isFalse, reason: '"Listen." at line starts');
      expect(name(inside: true, lower: true, uses: 5), isFalse, reason: 'written in lower case somewhere');
    });

    test('on, names at line starts and inside sentences go; off, they stay', () {
      final lines = ['Mortimer!', 'Mortimer, wait.', 'Call Ophelia now.', 'The drizzle.', 'Hush.', 'Hush.'];
      final on = SubtitleWordCounter.pick(lines, maximum: 10, level: EnglishLevel.a1).words;
      expect(on, isNot(contains('mortimer')));
      expect(on, isNot(contains('ophelia')));
      expect(on, containsAll(['drizzle', 'hush']));
      final off = SubtitleWordCounter.pick(lines, maximum: 10, level: EnglishLevel.a1, removeNames: false).words;
      expect(off, containsAll(['mortimer', 'ophelia', 'drizzle', 'hush']));
    });
  });

  test('numbers are never proposed: digits are not words, and numbers written as words are skipped at every level', () {
    final lines = ['Room 11, floor 90, in 1990.', 'Eleven ninety-nine.', 'The fourth gale, the twentieth gale.', 'A hundred thousand gales.'];
    for (final level in EnglishLevel.values) {
      final words = SubtitleWordCounter.pick(lines, maximum: 20, level: level).words;
      expect(words.where(SubtitleWordCounter.numberWords.contains), isEmpty, reason: level.label);
      expect(words.where((w) => RegExp(r'\d').hasMatch(w)), isEmpty, reason: level.label);
      expect(words, contains('gale'), reason: level.label);
    }
  });
}
