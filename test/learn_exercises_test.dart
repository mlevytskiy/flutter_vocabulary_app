import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_vocabulary_app/features/learn/exercises.dart';

void main() {
  test('the app exercise list matches the Worker exercises.json entry by entry', () {
    final raw = File('vocab-photo-api/src/learn/exercises.json').readAsStringSync();
    final json = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();

    expect(json.length, 13);
    expect(exercises.length, json.length);
    expect(exercises[1].id, 'dialogs-from-movie');
    expect(exercises[1].available, isTrue);
    for (var i = 0; i < json.length; i++) {
      expect(exercises[i].id, json[i]['id'], reason: 'id at $i');
      expect(exercises[i].name, json[i]['name'], reason: 'name at $i');
      expect(exercises[i].stage, json[i]['stage'], reason: 'stage at $i');
      expect(exercises[i].available, json[i]['available'], reason: 'available at $i');
    }
  });

  test('learn-kit S-02, AC-01: thirteen in plan order; only the four built ones available', () {
    expect([for (final e in exercises) '${e.stage} ${e.id} ${e.name}'], [
      '1 mnemonic-story Mnemonic story',
      '1 dialogs-from-movie Dialogs from movie',
      '1 match-synonyms Match synonyms',
      '1 match-definitions Match word and definition',
      '1 guess-my-word Guess my word',
      '1 pick-the-answer Pick the right answer',
      '2 fill-the-gaps Fill the gaps',
      '2 remember-or-not Remember or not',
      '2 sentence-patterns Sentence patterns',
      '3 own-sentences Make your own sentences',
      '3 translate-sentences Translate sentences',
      '3 explain-to-friend Explain it to a friend',
      '3 quiz Quiz',
    ]);
    expect([for (final e in exercises) if (e.available) e.id], ['mnemonic-story', 'dialogs-from-movie', 'match-synonyms', 'match-definitions', 'pick-the-answer', 'remember-or-not']);
  });
}
