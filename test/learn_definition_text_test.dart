import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_vocabulary_app/features/learn/kit/definition_text.dart';

/// learn-match-definitions: the definition line and the card text of a
/// definition (AC-07, AC-11, AC-12, AC-13, AC-14; S-40).
void main() {
  group('definitionText (S-40)', () {
    test('AC-07: a picked sense gives the text after "definition:", no example', () {
      expect(definitionText('definition: the land along the side of a river\nexample: We sat on the bank.'),
          'the land along the side of a river');
    });

    test('"definition:" in any case, found on any line', () {
      expect(definitionText('example: x\nDEFINITION:  a thing '), 'a thing');
    });

    test('AC-11: a Quizlet back plus example gives the first line', () {
      expect(definitionText('a place where ships stay\nThe harbour was full.'), 'a place where ships stay');
    });

    test('typed text is taken whole; example lines and blank lines are skipped', () {
      expect(definitionText('  a big dog  '), 'a big dog');
      expect(definitionText('\nExample: y\n\nthe meaning'), 'the meaning');
    });

    test('nothing usable gives ""', () {
      expect(definitionText(''), '');
      expect(definitionText('example: only an example'), '');
      expect(definitionText('definition:   '), '');
    });
  });

  group('definitionCard (S-40)', () {
    test('AC-12: whole-word places show as ___, in any case, with endings; not inside words or irregular forms', () {
      expect(definitionCard('Walk: to go on foot; she walks and walked home, not by sidewalk', 'walk'),
          '___: to go on foot; she ___ and ___ home, not by sidewalk');
      expect(definitionCard('to give up means to stop trying', 'give up'), 'to ___ means to stop trying');
      expect(definitionCard('to go; he went', 'go'), '___; he went'.replaceFirst('___;', 'to ___;'));
    });

    test('AC-13: a card that says nothing once masked is null', () {
      expect(definitionCard('Echo.', 'echo'), isNull);
      expect(definitionCard('echoes, echo', 'echo'), isNull);
      expect(definitionCard('', 'echo'), isNull);
      expect(definitionCard('example: only', 'echo'), isNull);
    });

    test('AC-14: first sentence within 120, else cut at a whole word plus …', () {
      final first = 'A' * 79 + '. ' + 'b' * 218;
      expect(definitionCard(first, 'zzz'), 'A' * 79 + '.');
      final long = List.filled(60, 'word').join(' ');
      final card = definitionCard(long, 'zzz')!;
      expect(card.endsWith('…'), isTrue);
      expect(card.length, lessThanOrEqualTo(121));
      expect(card.substring(0, card.length - 1).endsWith('word'), isTrue);
    });

    test('masking comes before cutting: the cut text is the masked text', () {
      final text = 'a ${'walk ' * 30}end';
      expect(definitionCard(text, 'walk'), 'a ${'___ ' * 29}…'.replaceAll(' …', '…'));
      expect(definitionCard('walk ' * 40, 'walk'), isNull);
    });
  });
}
