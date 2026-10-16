import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_vocabulary_app/features/words_table/safe_file_name.dart';

void main() {
  group('safeFileName (AC-32)', () {
    test('replaces ":" and "?" in a collection name', () {
      expect(safeFileName('Unit 3: phrasal verbs?'), 'Unit 3- phrasal verbs-');
    });

    test('keeps the dots of a default date name and replaces the colon', () {
      expect(safeFileName('16.10.2026 14:30'), '16.10.2026 14-30');
    });

    test('replaces each of the nine forbidden characters', () {
      expect(safeFileName(r'a\b/c:d*e?f"g<h>i|j'), 'a-b-c-d-e-f-g-h-i-j');
    });

    test('replaces control characters', () {
      expect(safeFileName('a\u0000b\tc\nd\u001Fe\u007Ff'), 'a-b-c-d-e-f');
    });

    test('falls back to "collection" when nothing is left', () {
      expect(safeFileName(''), 'collection');
      expect(safeFileName('   '), 'collection');
    });

    test('leaves an ordinary name unchanged', () {
      expect(safeFileName('Speaking club 12'), 'Speaking club 12');
    });
  });

  group('publicNameWarning (AC-31)', () {
    test('names the collection in the warning sentence', () {
      expect(
        publicNameWarning('Speaking club 12'),
        'The collection\'s name, "Speaking club 12", is visible to anyone with the link.',
      );
    });
  });
}
