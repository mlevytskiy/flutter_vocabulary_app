import '../models/vocab_word.dart';
import 'google_translate_service.dart';

/// Translates the words the phone picked from a subtitle file with Google
/// Translate in one request: the words go one per line and come back one per
/// line, in order. The context is the phone's own line
/// ([SubtitlePick.contexts]). No definition, no film dialogues, and no
/// part-of-speech choice — many lines bring no dictionary data, so each word
/// gets Google's plain translation. A word Google gives back unchanged (most
/// often a name or not a word) is left out, and the first [maximum] of the
/// rest are kept in the phone's order. A failed request fails the whole
/// import — never a partial list.
class SubtitleGoogleWords {
  SubtitleGoogleWords(this._google);

  final GoogleTranslateService _google;

  Future<List<VocabWord>> translate(
    List<String> words, {
    required Map<String, String> contexts,
    required int maximum,
  }) async {
    if (words.isEmpty) return const [];
    final result = await _google.translate(words.join('\n'), to: 'uk', from: 'en');
    final translations = result.text.split('\n').map((line) => line.trim()).toList();
    if (translations.length != words.length) {
      throw TranslationException('${words.length} words came back as ${translations.length} lines');
    }
    final kept = <VocabWord>[];
    for (var i = 0; i < words.length && kept.length < maximum; i++) {
      final translation = translations[i];
      if (translation.isEmpty || translation.toLowerCase() == words[i]) continue;
      kept.add(VocabWord(word: words[i], translation: translation, context: contexts[words[i]]));
    }
    return kept;
  }
}
