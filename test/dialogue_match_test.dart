import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_vocabulary_app/core/dialogues/dialogue_match.dart';

/// get-words-from-subtitles-improvment T13: the AC-05 matching rule in Dart,
/// checked against the Worker's own case file so the two cannot drift.
void main() {
  final file = File('vocab-photo-api/src/story/match-cases.json');
  final cases = (jsonDecode(file.readAsStringSync())['cases'] as List)
      .cast<Map<String, dynamic>>();

  test('the case file has cases', () => expect(cases, isNotEmpty));

  group('matchPlaces gives the same places as the Worker', () {
    for (final c in cases) {
      test(c['name'] as String, () {
        final expected = [
          for (final p in c['places'] as List) (p as List).cast<int>()
        ];
        final actual = [
          for (final p in matchPlaces(c['text'] as String, c['word'] as String))
            [p.start, p.end]
        ];
        expect(actual, expected);
        expect(appears(c['text'] as String, c['word'] as String),
            expected.isNotEmpty);
      });
    }
  });
}
