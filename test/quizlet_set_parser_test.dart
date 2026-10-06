import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_vocabulary_app/core/services/quizlet_page_script.dart';
import 'package:flutter_vocabulary_app/core/services/quizlet_set_parser.dart';

// The fixtures are SYNTHETIC (see test/fixtures/quizlet/README.txt); T17
// replaces them with material saved from real pages.
String fixture(String name) =>
    File('test/fixtures/quizlet/$name').readAsStringSync();

QuizletSet found(QuizletPageRead read) {
  expect(read, isA<QuizletSetFound>());
  return (read as QuizletSetFound).set;
}

void main() {
  const owner = '987534268';

  group('embedded data (AC-02, AC-08)', () {
    test('small set: name, stated count, cards in order with examples', () {
      final set = found(parseQuizletPage(
          fixture('embedded_small_with_examples.json'), owner));
      expect(set.setId, owner);
      expect(set.name, 'Job interview flash cards');
      expect(set.statedCount, 5);
      expect(set.cards.map((c) => c.term),
          ['reluctant', 'deadline', '', 'résumé', 'negotiate']);
      expect(
          set.cards.first,
          const QuizletCard(
              term: 'reluctant',
              back: 'not willing to do something',
              example: 'She was reluctant to answer.'));
      expect(set.cards[1].example, '');
      expect(set.cards[3].back, '');
      expect(set.cards[4].back, 'to discuss to reach an agreement\nline two');
      expect(set.cards[4].example, 'We negotiated the salary.');
    });

    test('image-only card is kept with an empty term, not dropped', () {
      final set = found(parseQuizletPage(
          fixture('embedded_small_with_examples.json'), owner));
      expect(set.cards[2].term, '');
      expect(set.cards[2].back, 'a picture of a handshake');
    });

    test('40 cards in set order from data nested in a string', () {
      final set = found(parseQuizletPage(
          fixture('embedded_nested_40_cards.json'), '555000111'));
      expect(set.name, 'Forty words');
      expect(set.statedCount, 40);
      expect(set.cards, hasLength(40));
      expect(set.cards.first.term, 'term 1');
      expect(set.cards.last.term, 'term 40');
      expect(set.cards[4].example, 'example 5');
    });
  });

  group('visible list fallback (AC-08)', () {
    test('used when the embedded data holds no cards', () {
      final set = found(parseQuizletPage(
          fixture('visible_fallback_12_cards.json'), '777222333'));
      expect(set.name, 'Travel basics');
      expect(set.statedCount, 13);
      expect(set.cards, hasLength(13));
      expect(set.cards.first,
          const QuizletCard(term: 'word 1', back: 'meaning 1'));
      expect(set.cards[2].example, 'sentence 3');
      expect(set.cards[4].term, '');
      expect(set.cards[4].back, 'a picture card');
    });
  });

  group('robot check, other sets, nothing yet (AC-05, AC-11)', () {
    test('robot check page is recognised', () {
      expect(parseQuizletPage(fixture('robot_check_page.json'), owner),
          isA<QuizletRobotCheck>());
    });

    test('every marker is recognised on its own', () {
      for (final marker in quizletRobotCheckMarkers) {
        final raw = jsonEncode({'setId': owner, 'robot': 'x $marker y'});
        expect(parseQuizletPage(raw, owner), isA<QuizletRobotCheck>(),
            reason: marker);
      }
    });

    test('material of another set id is ignored', () {
      expect(parseQuizletPage(fixture('other_set_page.json'), owner),
          isA<QuizletNothingYet>());
    });

    test('embedded data naming another set is ignored', () {
      final map =
          jsonDecode(fixture('embedded_small_with_examples.json')) as Map;
      map['setId'] = '111';
      expect(
          parseQuizletPage(jsonEncode(map), owner), isA<QuizletNothingYet>());
      final lying = jsonDecode(fixture('other_set_page.json')) as Map;
      lying['setId'] = owner; // page claims the asked set, data says another
      expect(
          parseQuizletPage(jsonEncode(lying), owner), isA<QuizletNothingYet>());
    });

    test('a page still loading is nothing yet', () {
      expect(parseQuizletPage(fixture('loading_page.json'), owner),
          isA<QuizletNothingYet>());
    });

    test('garbage never throws', () {
      for (final raw in ['', 'null', '"x"', '[1]', '{', '{"setId":5}']) {
        expect(parseQuizletPage(raw, owner), isA<QuizletNothingYet>(),
            reason: raw);
      }
    });
  });

  test('reader script is a self-contained expression returning JSON', () {
    expect(quizletPageScript, contains('JSON.stringify'));
    expect(quizletPageScript.trim(), startsWith('(function'));
  });
}
