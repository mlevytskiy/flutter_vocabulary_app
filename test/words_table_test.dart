import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_vocabulary_app/core/models/session.dart';
import 'package:flutter_vocabulary_app/core/models/source_photo.dart';
import 'package:flutter_vocabulary_app/core/models/word_pair.dart';
import 'package:flutter_vocabulary_app/core/providers.dart';
import 'package:flutter_vocabulary_app/core/services/session_publish_service.dart';
import 'package:flutter_vocabulary_app/core/services/source_photo_store.dart';
import 'package:flutter_vocabulary_app/features/word_input/word_input_notifier.dart';
import 'package:flutter_vocabulary_app/features/words_table/words_table_screen.dart';

/// definition-mode T14: the words table lists every filled row and shows the
/// columns the word detail mode shows (spec AC-12, AC-14).
void main() {
  final session = Session.create()
    ..words = [
      WordPair(word: 'claim', translation: 'заява', definition: 'to ask for'),
      WordPair(word: 'gated', definition: 'having a gate'),
      WordPair(word: 'curse', translation: 'прокляття'),
      WordPair(word: 'orphan'),
    ];

  Future<void> pumpTable(WidgetTester tester, WordDetailMode mode,
      {SessionPublishService? publisher, Session? shown}) async {
    final table = shown ?? session;
    SharedPreferences.setMockInitialValues({'word_detail_mode': mode.name});
    // The thumbnails read from a throwaway folder, not the platform's.
    final photoDir = Directory.systemTemp.createTempSync('words_table_test');
    addTearDown(() => photoDir.deleteSync(recursive: true));
    final container = ProviderContainer(overrides: [
      sessionByIdProvider(table.sessionId).overrideWith((ref) async => table),
      sourcePhotoStoreProvider
          .overrideWithValue(SourcePhotoStore(directory: photoDir.path)),
      if (publisher != null)
        sessionPublishServiceProvider.overrideWithValue(publisher),
    ]);
    addTearDown(container.dispose);
    await tester.runAsync(() async {
      container.read(wordDetailModeProvider);
      await container.read(wordDetailModeProvider.notifier).loaded;
      await container.read(sessionByIdProvider(table.sessionId).future);
    });
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp(home: WordsTableScreen(sessionId: table.sessionId)),
    ));
    await tester.pump();
  }

  List<String> headers(WidgetTester tester) => tester
      .widget<DataTable>(find.byType(DataTable))
      .columns
      .map((c) => ((c.label as Text).data)!)
      .toList();

  testWidgets('translation mode: word + translation, every filled row',
      (tester) async {
    await pumpTable(tester, WordDetailMode.translation);
    expect(headers(tester), ['#', 'Word', 'Translation']);
    expect(find.text('gated'), findsOneWidget); // definition-only row listed
    expect(find.text('orphan'), findsNothing); // a bare word is not filled
    expect(find.text('to ask for'), findsNothing);
  });

  testWidgets('definition mode: word + definition', (tester) async {
    await pumpTable(tester, WordDetailMode.definition);
    expect(headers(tester), ['#', 'Word', 'Definition']);
    expect(find.text('having a gate'), findsOneWidget);
    expect(find.text('заява'), findsNothing);
    expect(find.text('curse'), findsOneWidget); // translation-only row listed
  });

  testWidgets('both: all three columns', (tester) async {
    await pumpTable(tester, WordDetailMode.both);
    expect(headers(tester), ['#', 'Word', 'Translation', 'Definition']);
    expect(find.text('заява'), findsOneWidget);
    expect(find.text('to ask for'), findsOneWidget);
  });

  testWidgets('the Share button stops spinning once the link dialog is up',
      (tester) async {
    await pumpTable(tester, WordDetailMode.translation,
        publisher: _FakePublisher());
    await tester.tap(find.text('Share'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Share link'));
    // The clipboard write goes through a platform channel: let it answer.
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Link ready'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  // good-looking-web T19: the "include photos (N)" switch above the table, and
  // the sheet's warning: the 30-day photo note and the republish warning
  // (AC-23, AC-24, ADR-0008).
  SourcePhoto photo(String id, int minute) => SourcePhoto()
    ..id = id
    ..fileName = '$id.jpg'
    ..takenAt = DateTime(2026, 9, 20, 10, minute);

  Session withPhotos() => Session.create()
    ..words = [
      WordPair(word: 'claim', translation: 'заява', sourceId: 'p1'),
      WordPair(word: 'curse', translation: 'прокляття', sourceId: 'p2'),
      WordPair(word: 'gated', translation: 'з воротами', sourceId: 'p2'),
      WordPair(word: 'typed', translation: 'надрукований'),
      // A photo whose only row is blank is not counted.
      WordPair(sourceId: 'p3'),
    ]
    ..sources = [
      photo('p1', 1),
      photo('p2', 2),
      photo('p3', 3),
      photo('p4', 4)
    ];

  Future<void> openSheet(WidgetTester tester) async {
    await tester.tap(find.text('Share'));
    await tester.pumpAndSettle();
  }

  Future<void> tapShareLink(WidgetTester tester) async {
    await tester.tap(find.text('Share link'));
    await tester
        .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
  }

  const photosNote =
      'Included photos are visible to anyone with the link for 30 days.';
  const republishNote = 'This list was shared before. Sharing it again '
      'replaces the edits made on the shared page.';

  Session sharedBefore() => withPhotos()
    ..publishedId = 'old'
    ..editToken = 'token';

  Future<void> switchPhotosOff(WidgetTester tester) async {
    await tester.tap(find.byType(Switch));
    await tester.pump();
    expect(tester.widget<Switch>(find.byType(Switch)).value, isFalse);
  }

  testWidgets('photos with a linked row: the page has the switch on, with N',
      (tester) async {
    await pumpTable(tester, WordDetailMode.translation, shown: withPhotos());
    expect(find.text('Include photos (2)'), findsOneWidget);
    expect(tester.widget<Switch>(find.byType(Switch)).value, isTrue);
    // Above the table, not in the sheet.
    expect(tester.getTopLeft(find.byType(Switch)).dy,
        lessThan(tester.getTopLeft(find.byType(DataTable)).dy));
    await openSheet(tester);
    expect(find.text('Share file'), findsOneWidget); // file option unchanged
    expect(find.byType(Switch), findsOneWidget); // only the page's
  });

  testWidgets('no source photos: no switch and no note', (tester) async {
    await pumpTable(tester, WordDetailMode.translation);
    expect(find.byType(Switch), findsNothing);
    expect(find.textContaining('Include photos'), findsNothing);
    await openSheet(tester);
    expect(find.text('Share file'), findsOneWidget);
    expect(find.text('Share link'), findsOneWidget);
    expect(find.textContaining('30 days'), findsNothing);
  });

  testWidgets('photos only on blank rows count as none: no switch',
      (tester) async {
    final shown = Session.create()
      ..words = [
        WordPair(word: 'claim', translation: 'заява'),
        WordPair(sourceId: 'p1'),
      ]
      ..sources = [photo('p1', 1)];
    await pumpTable(tester, WordDetailMode.translation, shown: shown);
    expect(find.byType(Switch), findsNothing);
    await openSheet(tester);
    expect(find.textContaining('30 days'), findsNothing);
  });

  testWidgets('switch on publishes the session photos', (tester) async {
    final publisher = _FakePublisher();
    final shown = withPhotos();
    await pumpTable(tester, WordDetailMode.translation,
        publisher: publisher, shown: shown);
    await openSheet(tester);
    await tapShareLink(tester);
    expect(find.text('Link ready'), findsOneWidget);
    expect(publisher.sentSources!.map((p) => p.id), ['p1', 'p2', 'p3', 'p4']);
  });

  testWidgets('switch off publishes no photos (AC-24)', (tester) async {
    final publisher = _FakePublisher();
    await pumpTable(tester, WordDetailMode.translation,
        publisher: publisher, shown: withPhotos());
    await switchPhotosOff(tester);
    await openSheet(tester);
    await tapShareLink(tester);
    expect(find.text('Link ready'), findsOneWidget);
    expect(publisher.sentSources, isEmpty);
  });

  testWidgets('never shared, photos on: the sheet shows only the photo note',
      (tester) async {
    await pumpTable(tester, WordDetailMode.translation, shown: withPhotos());
    await openSheet(tester);
    expect(find.text(photosNote), findsOneWidget);
    expect(find.textContaining('shared before'), findsNothing);
  });

  testWidgets('never shared, photos off: no warning at all', (tester) async {
    await pumpTable(tester, WordDetailMode.translation, shown: withPhotos());
    await switchPhotosOff(tester);
    await openSheet(tester);
    expect(find.textContaining('30 days'), findsNothing);
    expect(find.textContaining('shared before'), findsNothing);
  });

  testWidgets('shared before, photos on: the longer warning', (tester) async {
    await pumpTable(tester, WordDetailMode.translation, shown: sharedBefore());
    await openSheet(tester);
    expect(find.text('$republishNote $photosNote'), findsOneWidget);
  });

  testWidgets('shared before, photos off: the republish warning only',
      (tester) async {
    await pumpTable(tester, WordDetailMode.translation, shown: sharedBefore());
    await switchPhotosOff(tester);
    await openSheet(tester);
    expect(find.text(republishNote), findsOneWidget);
    expect(find.textContaining('30 days'), findsNothing);
  });

  testWidgets('tapping the photo stack opens the viewer; swipe and close',
      (tester) async {
    await pumpTable(tester, WordDetailMode.translation, shown: withPhotos());
    await tester.tap(find.bySemanticsLabel('Show photos'));
    await tester.pumpAndSettle();
    // Only the photos with a linked row, as the switch counts them.
    expect(find.text('1 of 2'), findsOneWidget);
    await tester.fling(find.byType(PageView), const Offset(-400, 0), 1000);
    await tester.pumpAndSettle();
    expect(find.text('2 of 2'), findsOneWidget);
    await tester.tap(find.byTooltip('Previous photo'));
    await tester.pumpAndSettle();
    expect(find.text('1 of 2'), findsOneWidget);
    await tester.tap(find.byTooltip('Close the photos'));
    await tester.pumpAndSettle();
    expect(find.byType(PageView), findsNothing);
    // The switch was not toggled by the tap on its icon.
    expect(tester.widget<Switch>(find.byType(Switch)).value, isTrue);
  });

  testWidgets('the link in the dialog is a tappable link', (tester) async {
    await pumpTable(tester, WordDetailMode.translation,
        publisher: _FakePublisher());
    await openSheet(tester);
    await tapShareLink(tester);
    final link = find.text('https://example.test/s/id');
    expect(link, findsOneWidget);
    expect(find.ancestor(of: link, matching: find.byType(InkWell)),
        findsOneWidget);
  });

  testWidgets('the link dialog names the photos left out (spec OQ-3)',
      (tester) async {
    final publisher = _FakePublisher()..leftOut = [photo('p11', 11)];
    await pumpTable(tester, WordDetailMode.translation,
        publisher: publisher, shown: withPhotos());
    await openSheet(tester);
    await tapShareLink(tester);
    expect(
        find.text('1 photo was left out: a page holds the first '
            '10 photos taken.'),
        findsOneWidget);
  });

  // edit-session-from-history T4 (AC-01..AC-04, AC-06, AC-08): the red Edit
  // button and its question on a History session's words screen.
  group('Edit button', () {
    late Session current;
    late Session past;
    late _FakeWordInput input;
    late GoRouter router;

    Future<void> pumpHistoryTable(WidgetTester tester, String? shownId,
        {bool pastExists = true}) async {
      SharedPreferences.setMockInitialValues({});
      current = Session.create()
        ..words = [WordPair(word: 'coffee', translation: 'кава')];
      past = Session.create()
        ..words = [
          WordPair(word: 'tea', translation: 'чай'),
          WordPair(word: 'milk', translation: 'молоко'),
        ];
      input = _FakeWordInput(current, {
        current.sessionId: current,
        if (pastExists) past.sessionId: past,
      });
      final container = ProviderContainer(overrides: [
        wordInputNotifierProvider.overrideWith(() => input),
        sessionByIdProvider(past.sessionId).overrideWith((ref) async => past),
        sessionByIdProvider(current.sessionId)
            .overrideWith((ref) async => current),
      ]);
      addTearDown(container.dispose);
      await tester.runAsync(() async {
        await container.read(wordDetailModeProvider.notifier).loaded;
        await container.read(wordInputNotifierProvider.future);
        await container.read(sessionByIdProvider(past.sessionId).future);
        await container.read(sessionByIdProvider(current.sessionId).future);
      });
      router = GoRouter(
        initialLocation: shownId == null
            ? '/table'
            : '/table?sessionId=${shownId == 'past' ? past.sessionId : current.sessionId}',
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => const _MainStub(),
            routes: [
              GoRoute(
                path: 'table',
                builder: (context, state) => WordsTableScreen(
                    sessionId: state.uri.queryParameters['sessionId']),
              ),
            ],
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(routerConfig: router),
      ));
      await tester.pumpAndSettle();
    }

    Finder editButton() => find.widgetWithIcon(FloatingActionButton, Icons.edit);

    Future<void> askAndAnswer(WidgetTester tester, String answer) async {
      await tester.tap(editButton());
      await tester.pumpAndSettle();
      expect(find.text('Do you want to edit this list of words?'),
          findsOneWidget);
      await tester.tap(find.text(answer));
      await tester.pumpAndSettle();
    }

    testWidgets('a past session shows a round red Edit button',
        (tester) async {
      await pumpHistoryTable(tester, 'past');
      expect(editButton(), findsOneWidget);
      final fab = tester.widget<FloatingActionButton>(editButton());
      expect(fab.backgroundColor, Colors.red);
      expect(fab.tooltip, 'Edit');
    });

    testWidgets('no button for the current session', (tester) async {
      await pumpHistoryTable(tester, 'current');
      expect(editButton(), findsNothing);
    });

    testWidgets('no button without a sessionId', (tester) async {
      await pumpHistoryTable(tester, null);
      expect(editButton(), findsNothing);
    });

    testWidgets('No closes the question and changes nothing', (tester) async {
      await pumpHistoryTable(tester, 'past');
      await askAndAnswer(tester, 'No');

      expect(find.text('Do you want to edit this list of words?'),
          findsNothing);
      expect(find.byType(WordsTableScreen), findsOneWidget);
      expect(input.switchedTo, isEmpty);
      expect(find.text('tea'), findsOneWidget);
    });

    testWidgets('Yes opens the main screen on the picked words',
        (tester) async {
      await pumpHistoryTable(tester, 'past');
      await askAndAnswer(tester, 'Yes');

      expect(input.switchedTo, [past.sessionId]);
      expect(find.byType(WordsTableScreen), findsNothing);
      expect(find.text('main: tea, milk'), findsOneWidget);
      expect(router.canPop(), isFalse,
          reason: 'Back leaves the app, never back to History');
    });

    testWidgets('a session that is gone: a message, and it stays',
        (tester) async {
      await pumpHistoryTable(tester, 'past', pastExists: false);
      await askAndAnswer(tester, 'Yes');

      expect(find.text("This session can't be opened for editing"),
          findsOneWidget);
      expect(find.byType(WordsTableScreen), findsOneWidget);
      expect(find.byType(_MainStub), findsNothing);
    });
  });
}

/// Stands in for the main screen: shows the notifier's words.
class _MainStub extends ConsumerWidget {
  const _MainStub();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final words = ref.watch(wordInputNotifierProvider).valueOrNull?.words ??
        const <WordPair>[];
    return Scaffold(
      body: Text('main: ${words.map((w) => w.word).join(', ')}'),
    );
  }
}

/// The notifier without Isar: a map of sessions, and a log of switches.
class _FakeWordInput extends WordInputNotifier {
  _FakeWordInput(this._current, this._sessions);

  final Session _current;
  final Map<String, Session> _sessions;
  final List<String> switchedTo = [];

  @override
  Future<Session> build() async => _current;

  @override
  Future<bool> switchTo(String sessionId) async {
    final picked = _sessions[sessionId];
    if (picked == null) return false;
    switchedTo.add(sessionId);
    state = AsyncData(picked);
    return true;
  }
}


class _FakePublisher extends SessionPublishService {
  /// The photos the last publish was asked to include.
  List<SourcePhoto>? sentSources;

  /// What the fake answers as left out (spec OQ-3).
  List<SourcePhoto> leftOut = const [];

  @override
  Future<PublishedSession> publish(List<WordPair> pairs,
      {WordDetailMode detail = WordDetailMode.translation,
      List<SourcePhoto> sources = const [],
      String? publishedId,
      String? editToken}) async {
    sentSources = sources;
    return PublishedSession(
        id: 'id', url: 'https://example.test/s/id', leftOutSources: leftOut);
  }
}
