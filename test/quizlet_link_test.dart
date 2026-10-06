import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_vocabulary_app/core/services/quizlet_link.dart';

void main() {
  const plain = 'https://quizlet.com/987534268/job-interview-flash-cards/';

  group('QuizletLink.find: set link shapes (AC-02, AC-13)', () {
    final cases = <String, String>{
      'bare': 'quizlet.com/987534268/job-interview-flash-cards/',
      'bare without trailing slash':
          'quizlet.com/987534268/job-interview-flash-cards',
      'www bare': 'www.quizlet.com/987534268/job-interview-flash-cards/',
      'https': 'https://quizlet.com/987534268/job-interview-flash-cards/',
      'http': 'http://quizlet.com/987534268/job-interview-flash-cards/',
      'https www':
          'https://www.quizlet.com/987534268/job-interview-flash-cards/',
      'upper case host and scheme':
          'HTTPS://Quizlet.COM/987534268/job-interview-flash-cards/',
      'language part':
          'https://quizlet.com/ar/987534268/job-interview-flash-cards/',
      'language part with region':
          'https://quizlet.com/pt-br/987534268/job-interview-flash-cards/',
      'sharing extras':
          'https://quizlet.com/987534268/job-interview-flash-cards/?i=xxug6&x=1jqt',
      'language and extras (owner example)':
          'https://quizlet.com/ar/987534268/job-interview-flash-cards/?i=xxug6&x=1jqt',
      'fragment':
          'https://quizlet.com/987534268/job-interview-flash-cards/#top',
      'study mode':
          'https://quizlet.com/987534268/job-interview-flash-cards/flashcards/',
      'study mode with language and extras':
          'https://quizlet.com/de/987534268/job-interview-flash-cards/learn/?x=1jqt&i=xxug6',
      'share text':
          'Check out this set: https://quizlet.com/987534268/job-interview-flash-cards/?i=xxug6&x=1jqt\nStudy with me',
      'share text, link at the end of a sentence':
          'Look at quizlet.com/987534268/job-interview-flash-cards/.',
      'in angle brackets':
          '<https://quizlet.com/987534268/job-interview-flash-cards/>',
      'surrounded by spaces':
          '   https://quizlet.com/987534268/job-interview-flash-cards/   ',
      'second set ignored, first used':
          'https://quizlet.com/987534268/job-interview-flash-cards/ https://quizlet.com/111/other/',
      'another site first, then a set':
          'https://example.com/a https://quizlet.com/987534268/job-interview-flash-cards/',
    };
    cases.forEach((name, text) {
      test(name, () {
        final link = QuizletLink.find(text);
        expect(link, isNotNull);
        expect(link!.setId, '987534268');
        expect(link.plainUrl, plain);
      });
    });

    test('keeps a unicode and percent-encoded slug', () {
      final link =
          QuizletLink.find('https://quizlet.com/12345/слова_é-%D0%B0.b~c/?x=1');
      expect(link?.setId, '12345');
      expect(link?.plainUrl, 'https://quizlet.com/12345/слова_é-%D0%B0.b~c/');
    });

    test('plain link matches the Worker format', () {
      final link =
          QuizletLink.find('https://quizlet.com/ar/987534268/a-b/?x=1')!;
      expect(
        RegExp(r'^https://quizlet\.com/\d{1,20}/[\p{L}\p{N}_%.~-]+/$',
                unicode: true)
            .hasMatch(link.plainUrl),
        isTrue,
      );
    });
  });

  group('QuizletLink.find: refused text (AC-06)', () {
    final cases = <String, String>{
      'empty': '',
      'plain words': 'please import my set',
      'another site':
          'https://example.com/987534268/job-interview-flash-cards/',
      'another site with quizlet in query':
          'https://example.com/?u=quizlet.com/987534268/job-interview-flash-cards/',
      'another site with quizlet in path':
          'https://example.com/quizlet.com/987534268/job-interview-flash-cards/',
      'look-alike host':
          'https://notquizlet.com/987534268/job-interview-flash-cards/',
      'host continues':
          'https://quizlet.com.evil.com/987534268/job-interview-flash-cards/',
      'user info trick':
          'https://quizlet.com@evil.com/987534268/job-interview-flash-cards/',
      'folder': 'https://quizlet.com/user_name/folders/my-folder/sets',
      'folder with language':
          'https://quizlet.com/ar/user_name/folders/my-folder/sets/',
      'class': 'https://quizlet.com/class/123456/',
      'class with slug': 'https://quizlet.com/class/123456/my-class/',
      'user page': 'https://quizlet.com/user/someone/sets',
      'home page': 'https://quizlet.com/',
      'set id without a name': 'https://quizlet.com/987534268/',
      'id longer than 20 digits':
          'https://quizlet.com/123456789012345678901/name/',
      'dots-only name': 'https://quizlet.com/123/../',
    };
    cases.forEach((name, text) {
      test(name, () => expect(QuizletLink.find(text), isNull));
    });
  });

  group('QuizletLink.setIdOf', () {
    final cases = <String, String?>{
      'https://quizlet.com/987534268/name/': '987534268',
      'https://quizlet.com/ar/987534268/name/': '987534268',
      'https://quizlet.com/987534268/name/learn/?x=1': '987534268',
      'https://quizlet.com/987534268': '987534268',
      'https://quizlet.com/': null,
      'https://quizlet.com/login': null,
      'https://quizlet.com/class/123/': null,
    };
    cases.forEach((url, id) {
      test(url, () => expect(QuizletLink.setIdOf(Uri.parse(url)), id));
    });
  });

  group('QuizletLink.isNavigationAllowed (AC-11)', () {
    const id = '987534268';
    final allowed = <String>[
      'https://quizlet.com/987534268/job-interview-flash-cards/',
      'https://quizlet.com/ar/987534268/job-interview-flash-cards/?x=1',
      'https://www.quizlet.com/987534268/job-interview-flash-cards/flashcards/',
      'https://quizlet.com/987534268/other-name/',
      'https://quizlet.com/login',
      'https://quizlet.com/',
      'https://quizlet.com/challenge?return=1',
      'https://assets.quizlet.com/robot-check',
      'https://quizlet.com:443/987534268/a/',
    ];
    final refused = <String>[
      'https://quizlet.com/111/other-set/',
      'https://quizlet.com/ar/111/other-set/',
      'http://quizlet.com/987534268/job-interview-flash-cards/',
      'https://example.com/987534268/job-interview-flash-cards/',
      'https://evil.com/quizlet.com/987534268/',
      'https://notquizlet.com/',
      'https://quizlet.com.evil.com/',
      'https://quizlet.com@evil.com/',
      'https://quizlet.com./987534268/a/',
      'https://quizlet.com:8443/987534268/a/',
      'javascript:alert(1)',
      'intent://quizlet.com/#Intent;scheme=https;end',
      'itms-apps://apps.apple.com/app/quizlet',
      'about:blank',
      'file:///etc/passwd',
      'data:text/html,hi',
      '/987534268/relative/',
    ];
    for (final url in allowed) {
      test(
          'allows $url',
          () => expect(
              QuizletLink.isNavigationAllowed(Uri.parse(url), id), isTrue));
    }
    for (final url in refused) {
      test(
          'refuses $url',
          () => expect(
              QuizletLink.isNavigationAllowed(Uri.parse(url), id), isFalse));
    }
  });
}
