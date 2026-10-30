import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_vocabulary_app/core/models/session_source.dart';
import 'package:flutter_vocabulary_app/core/models/word_origin.dart';
import 'package:flutter_vocabulary_app/core/models/word_pair.dart';
import 'package:flutter_vocabulary_app/core/words/word_origin_rules.dart';

SessionSource _source(String id, SourceKind kind,
        {String? name, String? title}) =>
    SessionSource()
      ..id = id
      ..kind = kind
      ..name = name
      ..title = title;

void main() {
  group('originForRow (AC-02, AC-03)', () {
    final sources = [
      _source('p', SourceKind.photo),
      _source('q', SourceKind.set, name: 'Animals'),
      _source('f', SourceKind.subtitles, name: 'Friends.S02E05.720p.srt'),
      _source('m', SourceKind.subtitles, name: 'Inception'),
      _source('t', SourceKind.subtitles,
          name: 'show.2x07.srt', title: 'My show'),
    ];

    test('typed row and unknown source are manuallyEntered', () {
      expect(originForRow(WordPair(word: 'a'), sources).typeOfSource,
          SourceType.manuallyEntered);
      expect(
          originForRow(WordPair(word: 'a', sourceId: 'gone'), sources)
              .typeOfSource,
          SourceType.manuallyEntered);
    });

    test('photo → image, set → set', () {
      expect(originForRow(WordPair(sourceId: 'p'), sources).typeOfSource,
          SourceType.image);
      final set = originForRow(WordPair(sourceId: 'q'), sources);
      expect(set.typeOfSource, SourceType.set);
      expect(set.movieName, '');
    });

    test('subtitles → movie with name, season and episode', () {
      final o = originForRow(WordPair(sourceId: 'f'), sources);
      expect(o.typeOfSource, SourceType.movie);
      expect(o.movieName, 'Friends.S02E05.720p.srt');
      expect(o.season, 2);
      expect(o.episode, 5);
      expect(o.wasTranslationEditByUser, isFalse);
      expect(o.wasDescriptionEditByUser, isFalse);
    });

    test('a film without an episode keeps season and episode empty', () {
      final o = originForRow(WordPair(sourceId: 'm'), sources);
      expect(o.movieName, 'Inception');
      expect(o.season, isNull);
      expect(o.episode, isNull);
    });

    test("the learner's title names the film; the name gives the episode",
        () {
      final o = originForRow(WordPair(sourceId: 't'), sources);
      expect(o.movieName, 'My show');
      expect(o.season, 2);
      expect(o.episode, 7);
    });
  });

  group('edit flags (AC-04)', () {
    test('withEditedTranslation sets only its flag on a copy', () {
      final row = WordPair(word: 'cat', translation: 'кіт');
      final out = withEditedTranslation(row);
      expect(out.origin.wasTranslationEditByUser, isTrue);
      expect(out.origin.wasDescriptionEditByUser, isFalse);
      expect(out.translation, 'кіт');
      expect(row.origin.wasTranslationEditByUser, isFalse);
      expect(identical(out, row), isFalse);
      expect(identical(out.origin, row.origin), isFalse);
    });

    test('withEditedDefinition sets only its flag on a copy', () {
      final row = WordPair(word: 'cat');
      final out = withEditedDefinition(row);
      expect(out.origin.wasDescriptionEditByUser, isTrue);
      expect(out.origin.wasTranslationEditByUser, isFalse);
      expect(row.origin.wasDescriptionEditByUser, isFalse);
    });
  });

  test('withChangedWord clears context and flags, keeps type and film (AC-05)',
      () {
    final row = WordPair(
      word: 'cat',
      context: 'The cat sat.',
      contextKind: ContextKind.source,
      contextTried: true,
      sourceId: 'f',
    )..origin = (WordOrigin()
      ..typeOfSource = SourceType.movie
      ..movieName = 'Friends'
      ..season = 2
      ..episode = 5
      ..time = '00:01:02'
      ..wasTranslationEditByUser = true
      ..wasDescriptionEditByUser = true);
    final out = withChangedWord(row);
    expect(out.context, '');
    expect(out.contextKind, ContextKind.none);
    expect(out.contextTried, isFalse);
    expect(out.origin.wasTranslationEditByUser, isFalse);
    expect(out.origin.wasDescriptionEditByUser, isFalse);
    expect(out.origin.typeOfSource, SourceType.movie);
    expect(out.origin.movieName, 'Friends');
    expect(out.origin.season, 2);
    expect(out.origin.episode, 5);
    expect(out.origin.time, '00:01:02');
    expect(out.sourceId, 'f');
    // The input is untouched.
    expect(row.context, 'The cat sat.');
    expect(row.contextKind, ContextKind.source);
    expect(row.contextTried, isTrue);
    expect(row.origin.wasTranslationEditByUser, isTrue);
  });

  group('episodeFromFileName (AC-07)', () {
    void hit(String name, int season, int episode) => test(name, () {
          final r = episodeFromFileName(name);
          expect(r.season, season);
          expect(r.episode, episode);
        });
    void miss(String name) => test('no hit: $name', () {
          final r = episodeFromFileName(name);
          expect(r.season, isNull);
          expect(r.episode, isNull);
        });

    hit('Friends.S02E05.720p.srt', 2, 5);
    hit('friends s2e5.srt', 2, 5);
    hit('The.Office.2x05.srt', 2, 5);
    hit('show_S10E112_x264.srt', 10, 112);
    hit('Show - 3x12 - Title.srt', 3, 12);
    miss('Inception.2010.1920x1080.srt');
    miss('Movie 1999.srt');
    miss('movie.x264.srt');
    miss('Glasses.srt');
    miss('');
  });

  group('firstLineTime (AC-08)', () {
    final lines = [
      (start: const Duration(seconds: 3), text: 'Concatenate this.'),
      (start: const Duration(minutes: 1, seconds: 2), text: 'The CAT sat.'),
      (start: const Duration(hours: 1, minutes: 5, seconds: 9), text: 'cats'),
    ];

    test('the first whole-word match, as hh:mm:ss', () {
      expect(firstLineTime('cat', lines), '00:01:02');
    });

    test('hours are shown', () {
      expect(firstLineTime('cats', [lines[2]]), '01:05:09');
    });

    test('empty when no line has the word', () {
      expect(firstLineTime('dog', lines), '');
      expect(firstLineTime('cat', const []), '');
    });
  });
}
