// Unit tests for the pure response-parsing logic behind
// fetchTranslationWithDictionary. These test parseTranslationWithDictionaryResponse
// directly against real response bodies captured while empirically verifying
// the endpoint's shape (see that function's doc comment), without any live
// network call -- fast, deterministic, and independent of this undocumented
// third-party endpoint's availability.
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_vocabulary_app/services/google_translate_dictionary_service.dart';

void main() {
  group('parseTranslationWithDictionaryResponse', () {
    test('parses primary translation and flattened alternatives for "bank"',
        () {
      // Captured verbatim from a real translate.googleapis.com response for
      // q=bank&sl=en&tl=uk&dt=t&dt=bd (trimmed to the parts that matter).
      const body = '''
[[["банку","bank",null,null,3,null,null,[[]],[[["h","f"]]]]],
[["adjective",["банківський"],[["банківський",["bank","banking"]]],"bank",3],
["noun",["банк","берег","банк"],[["банк",["bank"]]],"bank",1]],
"en",null,null,null,null,[]]''';

      final result = parseTranslationWithDictionaryResponse(body);

      expect(result, isNotNull);
      expect(result!.primaryTranslation, 'банку');
      // "банк" appears in the noun list twice in this fixture -- confirms
      // de-duping works, alongside preserving flattened cross-group order.
      expect(result.alternatives, ['банківський', 'банк', 'берег']);
    });

    test('returns empty (not null) alternatives when dictionary data is absent',
        () {
      // Captured shape for a word Google has no dictionary entry for --
      // index 1 is simply omitted from the top-level array.
      const body = '[[["привіт","hi",null,null,3]],null,"en",null,null,null,null,[]]';

      final result = parseTranslationWithDictionaryResponse(body);

      expect(result, isNotNull);
      expect(result!.primaryTranslation, 'привіт');
      expect(result.alternatives, isEmpty);
    });

    test('concatenates multiple translation segments for the primary translation',
        () {
      const body = '[[["Привіт ",null],["Світ",null]],null,"en"]';

      final result = parseTranslationWithDictionaryResponse(body);

      expect(result, isNotNull);
      expect(result!.primaryTranslation, 'Привіт Світ');
    });

    test('returns null when the primary translation is empty', () {
      const body = '[[[""," "]],null,"en"]';

      expect(parseTranslationWithDictionaryResponse(body), isNull);
    });

    test('returns null for malformed/unexpected JSON', () {
      expect(parseTranslationWithDictionaryResponse('not json'), isNull);
      expect(parseTranslationWithDictionaryResponse('{}'), isNull);
      expect(parseTranslationWithDictionaryResponse('[]'), isNull);
      expect(parseTranslationWithDictionaryResponse('[null, null]'), isNull);
    });

    test('ignores malformed dictionary groups instead of throwing', () {
      const body = '''
[[["слово","word"]],
["not-a-group", 123, ["adjective"], ["noun", ["добре"]]],
"en"]''';

      final result = parseTranslationWithDictionaryResponse(body);

      expect(result, isNotNull);
      expect(result!.alternatives, ['добре']);
    });
  });
}
