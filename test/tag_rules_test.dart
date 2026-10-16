// T2 (collection-tags): the pure tag rules — validation (AC-04), keys and
// first-spelling-wins (AC-09), the 10-per-kind limit (AC-10), the same text as
// two kinds (AC-11), the preset lists (AC-31), the legacy sort and case merge
// (AC-17b, AC-31), word-start matching and ranking (AC-35), and the ≤ 50 ms
// ranking budget over 1,000 entries (spec §6).
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_vocabulary_app/core/models/tag_kind.dart';
import 'package:flutter_vocabulary_app/core/services/tag_rules.dart';

LibraryTag lib(
  String text, {
  TagKind kind = TagKind.topic,
  DateTime? lastUsedAt,
  bool forgotten = false,
}) =>
    (kind: kind, text: text, lastUsedAt: lastUsedAt, forgotten: forgotten);

List<String> texts(List<TagSuggestion> s) => [for (final x in s) x.text];

void main() {
  group('TagKind', () {
    test('ordinal order is fixed: origin first, topic second', () {
      expect(TagKind.values, [TagKind.origin, TagKind.topic]);
      expect(TagKind.origin.index, 0);
      expect(TagKind.topic.index, 1);
    });
  });

  group('tagProblem (AC-04)', () {
    test('accepts 1 to 30 characters on one line, spaces around ignored', () {
      expect(tagProblem('Food'), isNull);
      expect(tagProblem('  Food  '), isNull);
      expect(tagProblem('a' * 30), isNull);
      expect(tagProblem(' ${'a' * 30} '), isNull);
    });

    test('refuses empty, blank, too long and multi-line text', () {
      expect(tagProblem(''), tagProblemMessage);
      expect(tagProblem('   '), tagProblemMessage);
      expect(tagProblem('a' * 31), tagProblemMessage);
      expect(tagProblem('Fo\nod'), tagProblemMessage);
      expect(tagProblem('Fo\rod'), tagProblemMessage);
    });

    test('the message says 1 to 30 characters on one line', () {
      expect(tagProblemMessage, contains('1 to 30'));
      expect(tagProblemMessage, contains('one line'));
    });
  });

  group('tagKey', () {
    test('trims and ignores case', () {
      expect(tagKey('  Food '), 'food');
      expect(tagKey('FOOD'), tagKey('food'));
    });
  });

  group('limits (AC-10)', () {
    test('a list takes a tag while it holds fewer than 10', () {
      expect(maxTagsPerKind, 10);
      expect(maxTagLength, 30);
      expect(canAddTag(List.generate(9, (i) => 't$i')), isTrue);
      expect(canAddTag(List.generate(10, (i) => 't$i')), isFalse);
      expect(canAddTag(List.generate(14, (i) => 't$i')), isFalse);
    });
  });

  group('addTag', () {
    test('adds trimmed text at the end', () {
      final r = addTag(['Food'], '  Work ');
      expect(r.problem, isNull);
      expect(r.tags, ['Food', 'Work']);
    });

    test('a bad tag is a problem and the list is unchanged', () {
      final r = addTag(['Food'], 'a' * 31);
      expect(r.problem, tagProblemMessage);
      expect(r.tags, ['Food']);
    });

    test('a tag already there ignoring case adds nothing, no problem', () {
      final r = addTag(['Food'], 'food');
      expect(r.problem, isNull);
      expect(r.tags, ['Food']);
    });

    test('a known spelling wins over the typed one (AC-09, AC-35)', () {
      expect(
        addTag([], 'food', knownSpellings: ['Cooking', 'Food']).tags,
        ['Food'],
      );
      expect(
        addTag([], 'series', knownSpellings: originPresets).tags,
        ['Series'],
      );
    });

    test('new text is kept as typed when nothing known matches', () {
      expect(addTag([], 'fOdO', knownSpellings: ['Food']).tags, ['fOdO']);
    });

    test('the 11th tag is refused with the limit message (AC-10)', () {
      final ten = List.generate(10, (i) => 't$i');
      final r = addTag(ten, 'extra');
      expect(r.problem, tagLimitMessage);
      expect(r.tags, ten);
    });

    test('over-limit migrated lists keep everything, take nothing', () {
      final fourteen = List.generate(14, (i) => 't$i');
      final r = addTag(fourteen, 'extra');
      expect(r.problem, tagLimitMessage);
      expect(r.tags, fourteen);
    });

    test('the same text can join the other kind (AC-11)', () {
      final origin = addTag([], 'Travel').tags;
      final topic = addTag([], 'Travel').tags;
      expect(origin, ['Travel']);
      expect(topic, ['Travel']);
    });

    test('does not change the list it was given', () {
      final list = ['Food'];
      addTag(list, 'Work');
      expect(list, ['Food']);
    });
  });

  group('presets (AC-31)', () {
    test('origin presets in order', () {
      expect(originPresets, [
        'Book', 'Film', 'Series', 'Cartoon', 'Song', 'Podcast', 'YouTube',
        'Social media', 'Article', 'News', 'Textbook', 'Course', 'Lesson',
        'Quizlet', 'Game', 'Conversation', 'Travel', //
      ]);
    });

    test('topic presets in order', () {
      expect(topicPresets, [
        'Everyday life', 'Food', 'Travel', 'Work', 'Business', 'IT', 'Health',
        'Sport', 'Nature', 'Home', 'Shopping', 'Money', 'People', 'Emotions',
        'Education', 'Phrasal verbs', 'Idioms', 'Slang', 'Grammar',
        'Exam prep', //
      ]);
    });

    test('presetsFor picks the list of a kind', () {
      expect(presetsFor(TagKind.origin), originPresets);
      expect(presetsFor(TagKind.topic), topicPresets);
    });
  });

  group('sortLegacyTags and mergeCaseDuplicates (AC-17b, AC-31)', () {
    test('origin preset matches ignoring case go to origin, rest to topic', () {
      final r = sortLegacyTags(['Book', 'food', 'podcast', 'Friends']);
      expect(r.origin, ['Book', 'podcast']);
      expect(r.topic, ['food', 'Friends']);
    });

    test('an old untyped Travel becomes an origin tag', () {
      final r = sortLegacyTags(['Travel']);
      expect(r.origin, ['Travel']);
      expect(r.topic, isEmpty);
    });

    test('nothing is truncated or dropped, even past 10 or 30 characters', () {
      final tags = [for (var i = 0; i < 14; i++) 'other$i', 'x' * 40];
      final r = sortLegacyTags(tags);
      expect(r.topic, tags);
      expect(r.origin, isEmpty);
    });

    test('case duplicates merge into the first spelling, order kept', () {
      expect(
        mergeCaseDuplicates(['Travel', 'Food', 'travel', 'FOOD', 'Work']),
        ['Travel', 'Food', 'Work'],
      );
      expect(mergeCaseDuplicates([]), isEmpty);
    });
  });

  group('matchesWordStart (AC-08, AC-35)', () {
    test('co matches Cooking and Home cooking, not Tacos', () {
      expect(matchesWordStart('Cooking', 'co'), isTrue);
      expect(matchesWordStart('Home cooking', 'co'), isTrue);
      expect(matchesWordStart('Tacos', 'co'), isFalse);
    });

    test('ignores case and spaces around the query', () {
      expect(matchesWordStart('Cooking', ' CO '), isTrue);
    });

    test('a multi-word query matches from a word start', () {
      expect(matchesWordStart('Home cooking', 'home c'), isTrue);
      expect(matchesWordStart('Home cooking', 'cooking'), isTrue);
      expect(matchesWordStart('Home cooking', 'ome'), isFalse);
    });

    test('words split at punctuation too', () {
      expect(matchesWordStart('Self-study', 'study'), isTrue);
    });

    test('an empty query matches everything', () {
      expect(matchesWordStart('Anything', ''), isTrue);
      expect(matchesWordStart('Anything', '  '), isTrue);
    });
  });

  group('rankSuggestions (AC-35, AC-18, AC-12)', () {
    test('typing co: Cooking and Home cooking, not Tacos', () {
      final r = rankSuggestions(
        kind: TagKind.topic,
        library: [lib('Cooking'), lib('Home cooking'), lib('Tacos')],
        counts: {'cooking': 2, 'home cooking': 1, 'tacos': 5},
        presets: topicPresets,
        added: const [],
        query: 'co',
      );
      expect(texts(r), ['Cooking', 'Home cooking']);
    });

    test('order: in use by count, then last added, then unused, then presets',
        () {
      final r = rankSuggestions(
        kind: TagKind.topic,
        library: [
          lib('Unused old', lastUsedAt: DateTime(2026, 1, 1)),
          lib('Unused new', lastUsedAt: DateTime(2026, 3, 1)),
          lib('Few', lastUsedAt: DateTime(2026, 5, 1)),
          lib('Many', lastUsedAt: DateTime(2026, 1, 1)),
          lib('Tie old', lastUsedAt: DateTime(2026, 1, 1)),
          lib('Tie new', lastUsedAt: DateTime(2026, 2, 1)),
          lib('Migrated'), // lastUsedAt null, in use nowhere
        ],
        counts: {'many': 5, 'few': 1, 'tie old': 3, 'tie new': 3},
        presets: ['Preset one', 'Preset two'],
        added: const [],
        query: '',
        limit: 20,
      );
      expect(texts(r), [
        'Many', 'Tie new', 'Tie old', 'Few', //
        'Unused new', 'Unused old', 'Migrated', //
        'Preset one', 'Preset two',
      ]);
    });

    test('only presets are flagged as presets', () {
      final r = rankSuggestions(
        kind: TagKind.topic,
        library: [lib('Mine')],
        counts: {'mine': 1},
        presets: ['Food'],
        added: const [],
        query: '',
      );
      expect([for (final s in r) s.isPreset], [false, true]);
    });

    test('a forgotten tag is never offered (AC-12, AC-35)', () {
      final r = rankSuggestions(
        kind: TagKind.topic,
        library: [lib('Fodo', forgotten: true), lib('Food')],
        counts: {'fodo': 9, 'food': 1},
        presets: const [],
        added: const [],
        query: 'fo',
      );
      expect(texts(r), ['Food']);
    });

    test('tags of the other kind are not offered', () {
      final r = rankSuggestions(
        kind: TagKind.topic,
        library: [lib('Podcast', kind: TagKind.origin), lib('Pets')],
        counts: const {},
        presets: const [],
        added: const [],
        query: 'p',
      );
      expect(texts(r), ['Pets']);
    });

    test('already added tags are left out, ignoring case', () {
      final r = rankSuggestions(
        kind: TagKind.topic,
        library: [lib('Food'), lib('Work')],
        counts: const {},
        presets: ['Food', 'Money'],
        added: ['food'],
        query: '',
      );
      expect(texts(r), ['Work', 'Money']);
    });

    test('a preset the library already holds shows once, in the library spot',
        () {
      final r = rankSuggestions(
        kind: TagKind.topic,
        library: [lib('food')],
        counts: {'food': 1},
        presets: ['Food', 'Work'],
        added: const [],
        query: '',
      );
      expect(texts(r), ['food', 'Work']);
      expect(r.first.isPreset, isFalse);
    });

    test('a preset still shows when only a forgotten entry has its key', () {
      final r = rankSuggestions(
        kind: TagKind.topic,
        library: [lib('Food', forgotten: true)],
        counts: const {},
        presets: ['Food'],
        added: const [],
        query: '',
      );
      expect(texts(r), ['Food']);
      expect(r.single.isPreset, isTrue);
    });

    test('matching presets are found by word start', () {
      final r = rankSuggestions(
        kind: TagKind.topic,
        library: const [],
        counts: const {},
        presets: topicPresets,
        added: const [],
        query: 'zz',
      );
      expect(r, isEmpty);
      final r2 = rankSuggestions(
        kind: TagKind.topic,
        library: const [],
        counts: const {},
        presets: topicPresets,
        added: const [],
        query: 'verbs',
      );
      expect(texts(r2), ['Phrasal verbs']);
    });

    test('shows at most 8 by default, and at most limit when given', () {
      final library = [for (var i = 0; i < 20; i++) lib('Tag $i')];
      List<TagSuggestion> rank({int? limit}) => limit == null
          ? rankSuggestions(
              kind: TagKind.topic,
              library: library,
              counts: const {},
              presets: topicPresets,
              added: const [],
              query: '',
            )
          : rankSuggestions(
              kind: TagKind.topic,
              library: library,
              counts: const {},
              presets: topicPresets,
              added: const [],
              query: '',
              limit: limit,
            );
      expect(rank(), hasLength(8));
      expect(rank(limit: 3), hasLength(3));
      expect(maxSuggestions, 8);
    });

    test('1,000 library entries rank in 50 ms or less (spec §6)', () {
      final library = [
        for (var i = 0; i < 1000; i++)
          lib(
            i.isEven ? 'Cooking $i' : 'Tag $i',
            lastUsedAt: DateTime(2026, 1, 1).add(Duration(minutes: i)),
            forgotten: i % 50 == 0,
          ),
      ];
      final counts = {
        for (var i = 0; i < 1000; i += 3) tagKey(library[i].text): i % 7,
      };
      // Warm up the JIT, then time one call.
      for (var i = 0; i < 3; i++) {
        rankSuggestions(
          kind: TagKind.topic,
          library: library,
          counts: counts,
          presets: topicPresets,
          added: const ['Cooking 2'],
          query: 'co',
        );
      }
      final watch = Stopwatch()..start();
      final r = rankSuggestions(
        kind: TagKind.topic,
        library: library,
        counts: counts,
        presets: topicPresets,
        added: const ['Cooking 2'],
        query: 'co',
      );
      watch.stop();
      expect(r, hasLength(8));
      expect(watch.elapsedMilliseconds, lessThanOrEqualTo(50));
    });
  });
}
