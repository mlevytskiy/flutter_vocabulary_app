import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_vocabulary_app/core/services/quizlet_link.dart';
import 'package:flutter_vocabulary_app/features/word_input/quizlet_read_controller.dart';
import 'package:flutter_vocabulary_app/features/word_input/widgets/quizlet_progress_dialog.dart';

/// A page driver standing in for the web view: the test decides when the
/// page finishes loading, fails, and what the reader script returns.
class FakePageDriver implements QuizletPageDriver {
  Uri? opened;
  void Function()? _finished;
  void Function(String reason)? _failed;
  Object? Function() reply = () => '';
  int reads = 0;
  bool stopped = false;

  void finishLoading() => _finished!();
  void failLoading(String reason) => _failed!(reason);

  @override
  void open(
    Uri url, {
    required void Function() onPageFinished,
    required void Function(String reason) onLoadError,
  }) {
    opened = url;
    _finished = onPageFinished;
    _failed = onLoadError;
  }

  @override
  Future<Object?> runReader() async {
    reads++;
    return reply();
  }

  @override
  Widget buildView() =>
      const ColoredBox(key: Key('fake-page'), color: Colors.grey);

  @override
  void stop() => stopped = true;
}

const link = QuizletSetLink(
    setId: '123456', plainUrl: 'https://quizlet.com/123456/animals/');

String page({
  String setId = '123456',
  String name = 'Animals',
  List<List<String>>? cards,
  String robot = '',
}) =>
    jsonEncode({
      'setId': setId,
      'name': name,
      'heading': cards == null ? '' : 'Terms in this set (${cards.length})',
      'embedded': null,
      'visible': cards,
      'robot': robot,
    });

const twoCards = [
  ['cat', 'кіт'],
  ['dog', 'пес'],
];

/// import-from-quizlet T10: the progress dialog (SCR-03) — sad §4 waiting,
/// §6 F2, §8 web view boundary; AC-02, AC-05, AC-07, AC-07b, AC-11.
void main() {
  late FakePageDriver driver;
  late QuizletReadOutcome? result;

  Future<void> openDialog(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    driver = FakePageDriver();
    result = null;
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () async {
            result = await showQuizletProgressDialog(context, link,
                driverFactory: (_) => driver);
          },
          child: const Text('open'),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  double previewHeight(WidgetTester tester) =>
      tester.getSize(find.byKey(const Key('quizlet-preview'))).height;

  Future<void> wait(WidgetTester tester, int seconds) async {
    for (var i = 0; i < seconds * 4; i++) {
      await tester.pump(const Duration(milliseconds: 250));
    }
  }

  Future<void> settleClosed(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  testWidgets(
      'shows "Reading the Quizlet set…", a small live preview and Cancel, '
      'and opens the plain set link (AC-02)', (tester) async {
    await openDialog(tester);
    expect(find.text('Reading the Quizlet set…'), findsOneWidget);
    expect(find.byKey(const Key('fake-page')), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
    expect(driver.opened, Uri.parse(link.plainUrl));
    expect(previewHeight(tester), lessThanOrEqualTo(200));

    await tester.tap(find.text('Cancel'));
    await settleClosed(tester);
  });

  testWidgets('shows the set name as soon as it is known (AC-02)',
      (tester) async {
    await openDialog(tester);
    driver.finishLoading();
    driver.reply = () => page(name: 'Animals | Quizlet');
    await wait(tester, 2);
    expect(find.text('Animals'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await settleClosed(tester);
  });

  testWidgets('returns the parsed set once cards are found (AC-02)',
      (tester) async {
    await openDialog(tester);
    driver.finishLoading();
    driver.reply = () => page(cards: twoCards);
    await wait(tester, 2);
    await settleClosed(tester);

    expect(find.text('Reading the Quizlet set…'), findsNothing);
    expect(result, isA<QuizletReadSucceeded>());
    final set = (result as QuizletReadSucceeded).set;
    expect(set.setId, '123456');
    expect(set.name, 'Animals');
    expect(set.statedCount, 2);
    expect(set.cards.map((c) => c.term), ['cat', 'dog']);
    expect(driver.stopped, isTrue);
  });

  testWidgets('accepts the reader result quoted as JSON (Android)',
      (tester) async {
    await openDialog(tester);
    driver.finishLoading();
    driver.reply = () => jsonEncode(page(cards: twoCards));
    await wait(tester, 2);
    await settleClosed(tester);
    expect(result, isA<QuizletReadSucceeded>());
  });

  testWidgets(
      'a load error before the page has loaded ends with a failure '
      '(AC-07)', (tester) async {
    await openDialog(tester);
    driver.failLoading('hostLookup');
    await settleClosed(tester);

    expect(find.text('Reading the Quizlet set…'), findsNothing);
    expect(result, isA<QuizletReadFailed>());
    expect((result as QuizletReadFailed).reason, QuizletReadFailure.loadError);
    expect(driver.stopped, isTrue);
  });

  testWidgets('no first load within 30 s ends with a failure (AC-07)',
      (tester) async {
    await openDialog(tester);
    await wait(tester, 28);
    expect(result, isNull);
    expect(find.text('Reading the Quizlet set…'), findsOneWidget);

    await wait(tester, 3);
    await settleClosed(tester);
    expect(result, isA<QuizletReadFailed>());
    expect(
        (result as QuizletReadFailed).reason, QuizletReadFailure.noFirstLoad);
  });

  testWidgets(
      'the 30 s for cards start again when the page has loaded and end with '
      'a failure (AC-07)', (tester) async {
    await openDialog(tester);
    await wait(tester, 20);
    driver.finishLoading();
    await wait(tester, 20);
    expect(result, isNull, reason: 'the clock restarted at the first load');

    await wait(tester, 11);
    await settleClosed(tester);
    expect(result, isA<QuizletReadFailed>());
    expect((result as QuizletReadFailed).reason, QuizletReadFailure.noCards);
  });

  testWidgets('a load error after the page has loaded leaves it to the clock',
      (tester) async {
    await openDialog(tester);
    driver.finishLoading();
    await wait(tester, 2);
    driver.failLoading('connect');
    await tester.pump();
    expect(result, isNull);

    await tester.tap(find.text('Cancel'));
    await settleClosed(tester);
  });

  testWidgets(
      'a robot check makes the preview full size and pauses the clock, then '
      'the cards are read (AC-05)', (tester) async {
    await openDialog(tester);
    final small = previewHeight(tester);
    driver.finishLoading();
    await wait(tester, 10);

    driver.reply =
        () => page(name: 'Just a moment...', robot: 'Just a moment...');
    await wait(tester, 2);
    expect(previewHeight(tester), greaterThan(small * 2));

    await wait(tester, 60);
    expect(result, isNull, reason: 'the clock does not run during the check');

    driver.reply = () => page();
    await wait(tester, 2);
    expect(previewHeight(tester), small, reason: 'shrinks back once passed');

    driver.reply = () => page(cards: twoCards);
    await wait(tester, 2);
    await settleClosed(tester);
    expect(result, isA<QuizletReadSucceeded>());
  });

  testWidgets('a robot check also pauses the first-load clock (AC-05)',
      (tester) async {
    await openDialog(tester);
    driver.reply = () => page(robot: 'Attention Required! | Cloudflare');
    await wait(tester, 45);
    expect(result, isNull);

    driver.reply = () => '';
    await wait(tester, 31);
    await settleClosed(tester);
    expect(
        (result as QuizletReadFailed).reason, QuizletReadFailure.noFirstLoad);
  });

  testWidgets('cards of another set id are never read (AC-11)', (tester) async {
    await openDialog(tester);
    driver.finishLoading();
    driver.reply = () => page(setId: '999', name: 'Other', cards: twoCards);
    await wait(tester, 10);
    expect(find.text('Other'), findsNothing);
    expect(result, isNull);

    await wait(tester, 21);
    await settleClosed(tester);
    expect((result as QuizletReadFailed).reason, QuizletReadFailure.noCards);
  });

  testWidgets('a reader that throws keeps waiting', (tester) async {
    await openDialog(tester);
    driver.finishLoading();
    driver.reply = () => throw StateError('no document');
    await wait(tester, 3);
    expect(result, isNull);
    driver.reply = () => page(cards: twoCards);
    await wait(tester, 2);
    await settleClosed(tester);
    expect(result, isA<QuizletReadSucceeded>());
  });

  testWidgets('Cancel stops the import quietly (AC-07b)', (tester) async {
    await openDialog(tester);
    driver.finishLoading();
    await wait(tester, 3);
    await tester.tap(find.text('Cancel'));
    await settleClosed(tester);

    expect(find.text('Reading the Quizlet set…'), findsNothing);
    expect(result, isA<QuizletReadCancelled>());
    expect(driver.stopped, isTrue);
    final reads = driver.reads;
    await wait(tester, 5);
    expect(driver.reads, reads, reason: 'nothing is read after Cancel');
  });

  testWidgets('Back stops the import quietly (AC-07b)', (tester) async {
    await openDialog(tester);
    await tester.binding.handlePopRoute();
    await settleClosed(tester);

    expect(find.text('Reading the Quizlet set…'), findsNothing);
    expect(result, isA<QuizletReadCancelled>());
    expect(driver.stopped, isTrue);
  });

  group('allowWebViewNavigation (AC-11, ADR-0004)', () {
    bool allow(String url, {bool mainFrame = true}) =>
        allowWebViewNavigation(url, isMainFrame: mainFrame, setId: '123456');

    test('the set page and other Quizlet pages of the same set are allowed',
        () {
      expect(allow('https://quizlet.com/123456/animals/'), isTrue);
      expect(allow('https://quizlet.com/pt-br/123456/animals/'), isTrue);
      expect(allow('https://www.quizlet.com/cdn-cgi/challenge'), isTrue);
    });

    test('other sites, other sets, http and app links are refused', () {
      expect(allow('https://ads.example.com/x'), isFalse);
      expect(allow('https://quizlet.com/999/other/'), isFalse);
      expect(allow('http://quizlet.com/123456/animals/'), isFalse);
      expect(allow('itms-apps://apps.apple.com/app/id1'), isFalse);
      expect(allow('intent://scan#Intent;end'), isFalse);
      expect(allow('not a url %%'), isFalse);
    });

    test('embedded frames load as the page asks', () {
      expect(allow('https://challenges.cloudflare.com/x', mainFrame: false),
          isTrue);
    });
  });
}
