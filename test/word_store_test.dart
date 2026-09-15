import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_vocabulary_app/core/models/word_pair.dart';
import 'package:flutter_vocabulary_app/core/services/word_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('WordStore', () {
    test('round-trips pairs, including a tab and a newline', () async {
      SharedPreferences.setMockInitialValues({});
      final store = WordStore();
      final pairs = [
        WordPair(word: 'apple', translation: 'яблуко'),
        WordPair(word: 'with\ttab', translation: 'з\tтабом'),
        WordPair(word: 'multi\nline', translation: 'багато\nрядків'),
      ];

      await store.save(pairs);
      final loaded = await store.load();

      expect(loaded.length, 3);
      expect(loaded[0].word, 'apple');
      expect(loaded[0].translation, 'яблуко');
      expect(loaded[1].word, 'with\ttab');
      expect(loaded[1].translation, 'з\tтабом');
      expect(loaded[2].word, 'multi\nline');
      expect(loaded[2].translation, 'багато\nрядків');
    });

    test('load() returns [] when the store is empty', () async {
      SharedPreferences.setMockInitialValues({});
      final store = WordStore();

      expect(await store.load(), isEmpty);
    });

    test('load() returns [] for corrupt data instead of throwing', () async {
      SharedPreferences.setMockInitialValues({'word_pairs_v1': 'not json{{{'});
      final store = WordStore();

      expect(await store.load(), isEmpty);
    });

    test('load() returns [] when the stored JSON is not a list', () async {
      SharedPreferences.setMockInitialValues({'word_pairs_v1': '{"oops": true}'});
      final store = WordStore();

      expect(await store.load(), isEmpty);
    });
  });
}
