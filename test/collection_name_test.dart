// T3 (collections-screen): the name rule (AC-02), the default date name
// (AC-03) and the creation moment read from a collection id (AC-04).
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_vocabulary_app/core/models/collection_name.dart';

/// The cases T22 gives the Worker's title check too (api-sync-report A):
/// code points are counted on both sides, never UTF-16 units.
final nameCases = <(String label, String name, CollectionNameProblem? problem)>[
  ('empty', '', CollectionNameProblem.empty),
  ('only spaces', '   ', CollectionNameProblem.onlySpaces),
  ('one character', 'a', null),
  ('60 code points', 'a' * 60, null),
  ('61 code points', 'a' * 61, CollectionNameProblem.tooLong),
  ('an emoji counts as one', '😀' * 60, null),
  ('61 emoji', '😀' * 61, CollectionNameProblem.tooLong),
  ('a Cyrillic name', 'Фразові дієслова', null),
  ('60 Cyrillic letters', 'ж' * 60, null),
  ('a pasted line break', 'Phrasal\nverbs', CollectionNameProblem.lineBreak),
  ('a carriage return', 'Phrasal\r\nverbs', CollectionNameProblem.lineBreak),
  ('spaces around a word', '  Travel  ', null),
];

void main() {
  group('collectionNameProblem / isValidCollectionName (AC-02)', () {
    for (final (label, name, problem) in nameCases) {
      test(label, () {
        expect(collectionNameProblem(name), problem);
        expect(isValidCollectionName(name), problem == null);
      });
    }

    test('the limit is 60', () {
      expect(maxCollectionNameLength, 60);
    });
  });

  group('defaultCollectionName (AC-03)', () {
    test('is dd.MM.yyyy HH:mm', () {
      expect(defaultCollectionName(DateTime(2026, 10, 16, 14, 30, 59)),
          '16.10.2026 14:30');
    });

    test('pads day, month, hour and minute', () {
      expect(defaultCollectionName(DateTime(2026, 1, 2, 3, 4)),
          '02.01.2026 03:04');
    });

    test('shows a UTC moment in local time', () {
      final local = DateTime(2026, 10, 16, 14, 30);
      expect(defaultCollectionName(local.toUtc()), '16.10.2026 14:30');
    });
  });

  group('creationMomentOf (AC-04)', () {
    // The id format of WordCollection.create() (Session.create() before T2):
    // base-36 microseconds since epoch, '-', a base-36 random number.
    String idAt(DateTime moment) =>
        '${moment.microsecondsSinceEpoch.toRadixString(36)}-'
        '${Random().nextInt(1 << 32).toRadixString(36)}';

    test('reads the moment the id was made, in local time', () {
      final moment = DateTime(2025, 3, 9, 8, 15, 42, 123, 456);
      final read = creationMomentOf(idAt(moment));
      expect(read, moment);
      expect(read!.isUtc, isFalse);
      expect(defaultCollectionName(read), '09.03.2025 08:15');
    });

    for (final bad in [
      '',
      '-',
      'nodash',
      '-abc',
      'not base36!-abc',
      'zzzzzzzzzzzzzzzzzzzz-abc',
      '0-abc',
      'zzzzzzzzzzzz-abc',
    ]) {
      test('null for "$bad"', () {
        expect(creationMomentOf(bad), isNull);
      });
    }
  });
}
