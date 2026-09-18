// Live network smoke test -- run by hand, never in CI (`flutter test` must
// not touch the network; the offline contract test is
// `test/google_translate_service_test.dart`):
//
//   dart run tool/smoke_google_translate.dart
//
// Prints what Google answers today and checks the part-of-speech rule
// against the answers seen in 2026-09. A failure here means Google changed,
// not that the app broke.
import 'package:flutter_vocabulary_app/core/services/google_translate_service.dart';

Future<void> main() async {
  final service = GoogleTranslateService();
  var failures = 0;

  void check(String what, Object? actual, Object? expected) {
    final ok = '$actual' == '$expected';
    if (!ok) failures++;
    final want = ok ? '' : ' (want $expected)';
    print('${ok ? 'ok  ' : 'FAIL'} $what: $actual$want');
  }

  final home = await service.translate('home', from: 'en', to: 'uk');
  print('home: text=${home.text} alts=${home.alternatives} '
      'detected=${home.detectedSourceLanguage}');
  for (final entry in home.dictionary) {
    print('  ${entry.pos}: ${entry.wordList}');
  }
  check('home detected language', home.detectedSourceLanguage, 'en');
  check('home primary', home.text, 'додому');
  check(
    'home dictionary order',
    [for (final e in home.dictionaryByPriority) e.pos],
    ['noun', 'verb', 'adjective', 'adverb'],
  );

  // "the home" ranks будинок, домівка; only домівка is in the noun group.
  final homeWord = await service.translateWord('home', to: 'uk');
  check('home -> noun', homeWord.bestPos, 'noun');
  check('home best', homeWord.best, 'домівка');

  final book = await service.translateWord('book', to: 'uk');
  check('book -> noun', book.bestPos, 'noun');
  check('book best', book.best, 'книга'); // not "глава", Google's first noun

  final run = await service.translateWord('run', to: 'uk');
  check('run -> noun', run.bestPos, 'noun');

  final beautiful = await service.translateWord('beautiful', to: 'uk');
  check('beautiful -> adjective', beautiful.bestPos, 'adjective');

  final phrase = await service.translateWord('a home', to: 'uk');
  check('phrase has no part of speech', phrase.bestPos, null);
  check('phrase best', phrase.best, 'будинок');

  print(failures == 0 ? '\nall checks passed' : '\n$failures check(s) failed');
}
