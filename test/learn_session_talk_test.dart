import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_vocabulary_app/core/models/film_dialogue.dart';
import 'package:flutter_vocabulary_app/core/models/story_run.dart';
import 'package:flutter_vocabulary_app/core/models/word_box.dart';
import 'package:flutter_vocabulary_app/core/models/word_group.dart';
import 'package:flutter_vocabulary_app/core/models/word_pair.dart';
import 'package:flutter_vocabulary_app/core/providers.dart';
import 'package:flutter_vocabulary_app/core/services/collection_store.dart';
import 'package:flutter_vocabulary_app/core/services/story_run_store.dart';
import 'package:flutter_vocabulary_app/core/services/talk_api_service.dart';
import 'package:flutter_vocabulary_app/features/learn/session/leitner.dart';
import 'package:flutter_vocabulary_app/features/learn/session/session_result.dart';
import 'package:flutter_vocabulary_app/features/learn/talk/talk_notifier.dart';
import 'package:flutter_vocabulary_app/features/learn/talk/talk_rules.dart';

/// One call the fake talk service saw.
typedef TalkCall = ({String kind, String scene, List<TalkWord> words, String target, List<TalkLine> history});

/// A scripted [TalkApiService]: each call pops the next answer (a [TalkTurn]
/// or a [TalkApiException] to throw); with none left it echoes the target.
class FakeTalkApi implements TalkApiService {
  final calls = <TalkCall>[];
  final answers = <Object>[];

  Future<TalkTurn> _next(TalkCall call) async {
    calls.add(call);
    if (answers.isEmpty) return TalkTurn(reply: 'Tell me more.', target: call.target);
    final a = answers.removeAt(0);
    if (a is TalkApiException) throw a;
    return a as TalkTurn;
  }

  @override
  Future<TalkTurn> start({required String scene, required List<TalkWord> words, required String target}) =>
      _next((kind: 'start', scene: scene, words: words, target: target, history: const []));

  @override
  Future<TalkTurn> reply({
    required String scene,
    required List<TalkWord> words,
    required String target,
    required List<TalkLine> history,
  }) =>
      _next((kind: 'reply', scene: scene, words: words, target: target, history: history));
}

/// learn-redesign T17 (AC-20, AC-21, AC-22, AC-24; ADR-0007, ADR-0008, sad
/// §6.4): the talk rules, the Talk notifier over a fake API and a temporary
/// store, and finishSession. One Isar store for the whole file.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory dir;
  late CollectionStore store;
  late StoryRunStore runs;

  setUpAll(() async {
    final saved = HttpOverrides.current;
    HttpOverrides.global = null;
    try {
      await Isar.initializeIsarCore(download: true);
    } finally {
      HttpOverrides.global = saved;
    }
    SharedPreferences.setMockInitialValues({});
    dir = Directory.systemTemp.createTempSync('learn_session_talk_test');
    store = await CollectionStore.open(directory: dir.path);
    runs = await StoryRunStore.open(directory: dir.path);
  });

  tearDownAll(() async {
    await store.close();
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });

  final now = DateTime(2026, 10, 23, 10);

  WordPair pair(String word, String rowId) => WordPair(word: word, translation: 't-$word', rowId: rowId);

  /// A collection made through the store with [words] (rowIds r1, r2, …).
  Future<String> newCollection(List<String> words, {String? name, String? description}) async {
    final c = await store.create(keep: true, name: name, description: description);
    c.words = [for (var i = 0; i < words.length; i++) pair(words[i], 'r${i + 1}')];
    await store.put(c);
    return c.collectionId;
  }

  ProviderContainer container(FakeTalkApi api) {
    final c = ProviderContainer(overrides: [
      collectionStoreProvider.overrideWith((ref) async => store),
      storyRunStoreProvider.overrideWith((ref) async => runs),
      talkApiServiceProvider.overrideWithValue(api),
    ]);
    addTearDown(c.dispose);
    return c;
  }

  /// Starts a talk on [id] and keeps the provider alive for the test.
  Future<(ProviderContainer, Talk)> started(String id, FakeTalkApi api, {bool split = false}) async {
    final c = container(api);
    c.listen(talkProvider(id), (_, __) {}, fireImmediately: true);
    final talk = c.read(talkProvider(id).notifier);
    await talk.start(split: split, now: now);
    return (c, talk);
  }

  group('talk rules', () {
    final words = [pair('crowded', 'a'), pair('take off', 'b'), pair('ticket', 'c')];

    test('usedWords: whole-word matchPlaces on the learner text, phrases and endings', () {
      expect(usedWords('The bus was so crowded!', words), {'a'});
      expect(usedWords('We take off at noon and buy tickets', words), {'b', 'c'});
      expect(usedWords('overcrowded tick', words), isEmpty);
    });

    test('hintDue after two replies without the target', () {
      expect(hintDue(0), isFalse);
      expect(hintDue(1), isFalse);
      expect(hintDue(2), isTrue);
      expect(hintDue(3), isTrue);
    });

    test('scenePick: story, else dialogue, else name and description', () {
      expect(scenePick(storyText: 'A story', dialogueText: 'A: hi', name: 'Trip', description: 'Words'), 'A story');
      expect(scenePick(storyText: ' ', dialogueText: 'A: hi', name: 'Trip', description: 'Words'), 'A: hi');
      expect(scenePick(name: 'Trip', description: 'Airport words'), 'Trip\nAirport words');
      expect(scenePick(name: 'Trip'), 'Trip');
    });

    test('scoreTalk: used clean, used after its hint missed, never used unused (AC-22)', () {
      final out = scoreTalk(words, used: {'a', 'b'}, hinted: {'b', 'c'});
      expect(out[words[0]], WordOutcome.clean);
      expect(out[words[1]], WordOutcome.missed);
      expect(out[words[2]], WordOutcome.unused);
    });

    test('talkOver after 12 replies or when every word is used', () {
      expect(talkOver(11, 2, 3), isFalse);
      expect(talkOver(12, 0, 3), isTrue);
      expect(talkOver(3, 3, 3), isTrue);
      expect(talkOver(0, 0, 0), isFalse);
    });
  });

  group('Talk notifier', () {
    test('starts with the picked words and the opening; scene falls back to name + description', () async {
      final id = await newCollection(['crowded', 'ticket', 'gate'], name: 'Airport', description: 'Words for flying');
      final api = FakeTalkApi()..answers.add(const TalkTurn(reply: 'Welcome aboard!', target: 'ticket'));
      final (c, _) = await started(id, api);
      final s = c.read(talkProvider(id));
      expect(s.status, TalkStatus.talking);
      expect(api.calls.single.kind, 'start');
      expect(api.calls.single.scene, 'Airport\nWords for flying');
      expect([for (final w in api.calls.single.words) w.word], ['crowded', 'ticket', 'gate']);
      expect(api.calls.single.target, 'crowded');
      expect(s.target, 'ticket');
      expect([for (final w in s.words) w.word.word], ['crowded', 'ticket', 'gate']);
      expect(s.messages.single.role, TalkRole.ai);
      expect(s.messages.single.text, 'Welcome aboard!');
    });

    test('from 20 words a split talk takes one session group, as Exercises would (AC-20)', () async {
      final id = await newCollection([for (var i = 0; i < 24; i++) 'word$i']);
      final api = FakeTalkApi();
      final (c, _) = await started(id, api, split: true);
      final picked = [for (final w in c.read(talkProvider(id)).words) w.word.word];
      expect(picked, [for (var i = 0; i < 12; i++) 'word$i']);
      expect(api.calls.single.words.length, 12);
    });

    test('scene: the story text of the group holding the words, else a film dialogue', () async {
      final id = await newCollection(['crowded', 'ticket', 'gate']);
      final run = StoryRun()
        ..runId = 'run-1'
        ..collectionId = id
        ..groupId = 'g1'
        ..groupName = 'Travel'
        ..startedAt = now
        ..outcome = 'done'
        ..steps = [
          StoryStep()
            ..role = 'story'
            ..outcome = 'done'
            ..text = 'Once at a crowded gate…',
        ];
      await runs.put(run);
      await store.update(id, (col) {
        col.groups = [
          WordGroup()
            ..id = 'g1'
            ..name = 'Travel'
            ..rowIds = ['r1', 'r2', 'r3']
            ..storyRunId = 'run-1',
        ];
        col.dialogues = [
          FilmDialogue()
            ..id = 'd1'
            ..lines = ['A: Hello', 'B: Hi'],
        ];
      });
      final api = FakeTalkApi();
      await started(id, api);
      expect(api.calls.single.scene, 'Once at a crowded gate…');

      // Without the story: the first shown film dialogue's lines.
      await store.update(id, (col) {
        col.groups = [];
        col.dialogues = [
          FilmDialogue()
            ..id = 'd0'
            ..hidden = true
            ..lines = ['hidden'],
          FilmDialogue()
            ..id = 'd1'
            ..lines = ['A: Hello', 'B: Hi'],
        ];
      });
      final api2 = FakeTalkApi();
      await started(id, api2);
      expect(api2.calls.single.scene, 'A: Hello\nB: Hi');
    });

    test('only the learner text ticks words; an AI reply with a word ticks nothing (AC-21)', () async {
      final id = await newCollection(['crowded', 'ticket', 'gate']);
      final api = FakeTalkApi()
        ..answers.addAll([
          const TalkTurn(reply: 'Was the gate crowded? You used ticket well!', target: 'crowded'),
          const TalkTurn(reply: 'Nice, and the ticket?', target: 'ticket'),
        ]);
      final (c, talk) = await started(id, api);
      expect(c.read(talkProvider(id)).words.where((w) => w.used), isEmpty);

      await talk.send('It was so crowded');
      final s = c.read(talkProvider(id));
      expect({for (final w in s.words) if (w.used) w.word.word}, {'crowded'});
      expect(s.repliesCount, 1);
      expect(s.target, 'ticket');
      expect(api.calls.last.kind, 'reply');
      expect(api.calls.last.history.last.role, 'learner');
      expect(api.calls.last.history.last.text, 'It was so crowded');
    });

    test('Hint after two replies without the target; showHint marks it hinted', () async {
      final id = await newCollection(['crowded', 'ticket', 'gate']);
      final api = FakeTalkApi()..answers.add(const TalkTurn(reply: 'Hi', target: 'gate'));
      final (c, talk) = await started(id, api);
      await talk.send('Hello there');
      expect(c.read(talkProvider(id)).hintAvailable, isFalse);
      await talk.send('I like planes');
      final s = c.read(talkProvider(id));
      expect(s.hintAvailable, isTrue);
      expect(s.hintWord, isNull);
      talk.showHint();
      expect(c.read(talkProvider(id)).hintWord, 'gate');
      expect(c.read(talkProvider(id)).hinted, {'r3'});
    });

    test('ends by itself after 12 learner replies (AC-20)', () async {
      final id = await newCollection(['crowded', 'ticket', 'gate']);
      final api = FakeTalkApi();
      final (c, talk) = await started(id, api);
      for (var i = 0; i < 12; i++) {
        await talk.send('Reply number $i');
      }
      final s = c.read(talkProvider(id));
      expect(s.status, TalkStatus.over);
      expect(s.repliesCount, 12);
      // The 12th reply ends the talk without asking the AI again.
      expect(api.calls.where((x) => x.kind == 'reply').length, 11);
      expect(c.read(lastSessionResultProvider)?.kind, SessionKind.talk);
    });

    test('ends by itself when every word is used', () async {
      final id = await newCollection(['crowded', 'ticket']);
      final api = FakeTalkApi();
      final (c, talk) = await started(id, api);
      await talk.send('A crowded hall');
      expect(c.read(talkProvider(id)).status, TalkStatus.talking);
      await talk.send('Where is my ticket?');
      expect(c.read(talkProvider(id)).status, TalkStatus.over);
    });

    test('Done scores used / hinted / unused and writes boxes once (AC-22)', () async {
      final id = await newCollection(['crowded', 'ticket', 'gate']);
      await store.update(id, (col) {
        col.boxes = [
          WordBox()
            ..rowId = 'r3'
            ..word = 'gate'
            ..box = 3
            ..dueAt = DateTime(2026, 10, 23)
            ..lastUpDay = '',
        ];
      });
      final api = FakeTalkApi()
        ..answers.addAll([
          const TalkTurn(reply: 'Hello', target: 'ticket'),
          const TalkTurn(reply: 'Ok', target: 'ticket'),
          const TalkTurn(reply: 'Ok', target: 'ticket'),
          const TalkTurn(reply: 'Ok', target: 'gate'),
        ]);
      final (c, talk) = await started(id, api);
      await talk.send('It was crowded'); // crowded used, no hint
      await talk.send('Nothing'); // 2nd reply without ticket
      talk.showHint();
      await talk.send('My ticket is lost'); // ticket used after its hint
      await talk.finish();

      final s = c.read(talkProvider(id));
      expect(s.status, TalkStatus.over);
      final result = c.read(lastSessionResultProvider)!;
      expect(result.kind, SessionKind.talk);
      expect(result.written, isTrue);
      expect(result.unusedCount, 1);
      final states = {for (final m in result.moves) m.word: m.state};
      expect(states, {'crowded': WordState.knownWell, 'ticket': WordState.isNew, 'gate': WordState.unused});

      final stored = (await store.byId(id))!;
      final boxes = {for (final b in stored.boxes) b.rowId: b};
      expect(boxes['r1']!.box, 1);
      expect(boxes['r2']!.box, 1);
      expect(boxes['r3']!.box, 3); // never used: box and next review kept
      expect(boxes['r3']!.dueAt, DateTime(2026, 10, 23));

      // A second Done writes nothing more.
      await talk.finish();
      expect((await store.byId(id))!.boxes.length, 3);
    });

    test('leaving without Done writes nothing', () async {
      final id = await newCollection(['crowded', 'ticket']);
      final api = FakeTalkApi();
      final (c, talk) = await started(id, api);
      await talk.send('So crowded');
      c.dispose();
      expect((await store.byId(id))!.boxes, isEmpty);
    });

    test('the day limit on start shows its message (AC-24)', () async {
      final id = await newCollection(['crowded']);
      final api = FakeTalkApi()..answers.add(TalkApiException(TalkApiError.dayLimit, 'status 429'));
      final (c, _) = await started(id, api);
      final s = c.read(talkProvider(id));
      expect(s.status, TalkStatus.limit);
      expect(s.errorText, "Today's talk limit is reached. Try again tomorrow.");
    });

    test('a failed reply keeps the typed text; retry sends it again', () async {
      final id = await newCollection(['crowded', 'ticket']);
      final api = FakeTalkApi()
        ..answers.addAll([
          const TalkTurn(reply: 'Hi', target: 'crowded'),
          TalkApiException(TalkApiError.network, 'offline'),
        ]);
      final (c, talk) = await started(id, api);
      await talk.send('Hello friend');
      var s = c.read(talkProvider(id));
      expect(s.status, TalkStatus.error);
      expect(s.keepDraft, 'Hello friend');
      expect(s.errorText, isNotEmpty);
      expect(s.repliesCount, 0);
      expect(s.messages.length, 1);

      await talk.retry();
      s = c.read(talkProvider(id));
      expect(s.status, TalkStatus.talking);
      expect(s.keepDraft, isNull);
      expect(s.repliesCount, 1);
      expect(s.messages.map((m) => m.text), ['Hi', 'Hello friend', 'Tell me more.']);
    });

    test('reply history is capped at the latest 24 lines', () async {
      final words = [for (var i = 0; i < 15; i++) 'word$i'];
      final id = await newCollection(words);
      final api = FakeTalkApi();
      final (_, talk) = await started(id, api);
      for (var i = 0; i < 11; i++) {
        await talk.send('plain line $i');
      }
      // The 11th reply call carries the opening, 10 earlier exchanges and the
      // new learner line: 22 lines, under the Worker's 24 (ADR-0007).
      expect(api.calls.last.history.length, 22);
      expect(capHistory([for (var i = 0; i < 30; i++) TalkLine(role: 'ai', text: '$i')]).map((l) => l.text).first, '6');
      expect(capHistory([for (var i = 0; i < 30; i++) TalkLine(role: 'ai', text: '$i')]).length, 24);
    });
  });

  group('finishSession', () {
    test('writes the moved boxes in one update and returns written = true', () async {
      final id = await newCollection(['walk', 'run']);
      final c = (await store.byId(id))!;
      final result = await finishSession(
        store: store,
        collectionId: id,
        outcomes: {c.words[0]: WordOutcome.clean, c.words[1]: WordOutcome.missed},
        kind: SessionKind.exercises,
        now: now,
        groupIndex: 1,
        groupCount: 3,
        pages: 7,
      );
      expect(result.written, isTrue);
      expect(result.collectionId, id);
      expect(result.moves.map((m) => m.state), [WordState.knownWell, WordState.isNew]);
      expect(result.groupIndex, 1);
      expect(result.groupCount, 3);
      expect(result.pages, 7);
      expect((await store.byId(id))!.boxes.length, 2);
    });

    test('an erased collection gives the moves with written = false', () async {
      final id = await newCollection(['walk']);
      final c = (await store.byId(id))!;
      await store.delete(id);
      final result = await finishSession(
        store: store,
        collectionId: id,
        outcomes: {c.words[0]: WordOutcome.clean},
        kind: SessionKind.talk,
        now: now,
      );
      expect(result.written, isFalse);
      expect(result.moves.single.state, WordState.knownWell);
      expect(await store.byId(id), isNull);
    });

    test('a null collection id is the current collection', () async {
      final id = await newCollection(['walk']);
      await store.setCurrentCollectionId(id);
      final c = (await store.byId(id))!;
      final result = await finishSession(
        store: store,
        collectionId: null,
        outcomes: {c.words[0]: WordOutcome.unused},
        kind: SessionKind.talk,
        now: now,
      );
      expect(result.collectionId, id);
      expect(result.written, isTrue);
      expect(result.unusedCount, 1);
    });
  });
}
