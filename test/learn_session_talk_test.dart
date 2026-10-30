import 'dart:io';
import 'dart:typed_data';

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
import 'package:flutter_vocabulary_app/core/services/learn_api_service.dart';
import 'package:flutter_vocabulary_app/core/services/story_run_store.dart';
import 'package:flutter_vocabulary_app/core/services/talk_api_service.dart';
import 'package:flutter_vocabulary_app/core/services/talk_picture_service.dart';
import 'package:flutter_vocabulary_app/features/learn/session/leitner.dart';
import 'package:flutter_vocabulary_app/features/learn/session/self_check.dart';
import 'package:flutter_vocabulary_app/features/learn/session/session_result.dart';
import 'package:flutter_vocabulary_app/features/learn/talk/talk_notifier.dart';
import 'package:flutter_vocabulary_app/features/learn/talk/talk_quiz.dart';
import 'package:flutter_vocabulary_app/features/learn/talk/talk_rules.dart';

/// One call the fake talk service saw.
typedef TalkCall = ({String kind, String scene, List<TalkWord> words, String target, List<TalkLine> history});

/// A scripted [TalkApiService]: each call pops the next answer (a [TalkTurn]
/// or a [TalkApiException] to throw); with none left it echoes the target.
class FakeTalkApi implements TalkApiService {
  final calls = <TalkCall>[];
  final answers = <Object>[];

  /// The Learn flow's topic and reply limit each call sent (learn-welcome
  /// T15), in step with [calls].
  final flows = <({TalkTopic? topic, int? maxReplies})>[];

  Future<TalkTurn> _next(TalkCall call) async {
    calls.add(call);
    if (answers.isEmpty) return TalkTurn(reply: 'Tell me more.', target: call.target);
    final a = answers.removeAt(0);
    if (a is TalkApiException) throw a;
    return a as TalkTurn;
  }

  @override
  Future<TalkTurn> start({
    required String scene,
    required List<TalkWord> words,
    required String target,
    TalkTopic? topic,
    int? maxReplies,
  }) {
    flows.add((topic: topic, maxReplies: maxReplies));
    return _next((kind: 'start', scene: scene, words: words, target: target, history: const []));
  }

  @override
  Future<TalkTurn> reply({
    required String scene,
    required List<TalkWord> words,
    required String target,
    required List<TalkLine> history,
    TalkTopic? topic,
    int? maxReplies,
  }) {
    flows.add((topic: topic, maxReplies: maxReplies));
    return _next((kind: 'reply', scene: scene, words: words, target: target, history: history));
  }
}

/// A talk picture service that answers [bytes] (null: no picture) and
/// remembers the prompts (talk-mission).
/// Exercise data for the talk's quick check: a sentence and a definition
/// for every word (talk quiz, owner 2026-10-24).
class FakeQuizData implements LearnApiService {
  @override
  Future<Map<String, T?>> fetchData<T>(LearnDataKind<T> kind, List<LearnWord> words) async => {
        for (final w in words)
          w.rowId: (kind.wire == 'definition' ? (definition: 'Meaning of ${w.word}.') : (sentence: 'We saw the ${w.word} today.'))
              as T,
      };

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeTalkPicture extends TalkPictureService {
  Uint8List? bytes;
  final prompts = <String>[];

  @override
  Future<Uint8List?> draw(String prompt) async {
    prompts.add(prompt);
    return bytes;
  }
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

  ProviderContainer container(FakeTalkApi api, {FakeTalkPicture? pictures}) {
    final c = ProviderContainer(overrides: [
      collectionStoreProvider.overrideWith((ref) async => store),
      storyRunStoreProvider.overrideWith((ref) async => runs),
      talkApiServiceProvider.overrideWithValue(api),
      talkPictureServiceProvider.overrideWithValue(pictures ?? FakeTalkPicture()),
      learnApiServiceProvider.overrideWithValue(FakeQuizData()),
    ]);
    addTearDown(c.dispose);
    return c;
  }

  /// Starts a talk on [id] and keeps the provider alive for the test.
  Future<(ProviderContainer, Talk)> started(String id, FakeTalkApi api,
      {bool split = false, FakeTalkPicture? pictures}) async {
    final c = container(api, pictures: pictures);
    c.listen(talkProvider(id), (_, __) {}, fireImmediately: true);
    final talk = c.read(talkProvider(id).notifier);
    await talk.start(split: split, now: now);
    return (c, talk);
  }

  test('mixed choices never tick words, including after a failed choice is retried', () async {
    final id = await newCollection(['ticket', 'crowded']);
    final api = FakeTalkApi()
      ..answers.add(const TalkTurn(
          reply: 'What will you do?', target: 'ticket', interaction: 'choice', choices: ['Buy a ticket', 'Walk away']));
    final (c, talk) = await started(id, api);
    api.answers.add(TalkApiException(TalkApiError.network, 'offline'));
    await talk.send('Buy a ticket', isChoice: true);
    expect(c.read(talkProvider(id)).repliesCount, 0);
    expect(c.read(talkProvider(id)).keepChoice, isTrue);
    api.answers
        .add(const TalkTurn(reply: 'Where next?', target: 'ticket', interaction: 'choice', choices: ['Stay', 'Leave']));
    await talk.retry();
    expect(c.read(talkProvider(id)).usedCount, 0);
    expect(c.read(talkProvider(id)).repliesCount, 1);
    expect(api.calls.last.history.last.toJson()['source'], 'choice');
    await talk.finish(now: now);
    expect((await store.byId(id))!.boxes, isEmpty);
  });

  test('mixed speech counts independently; hints count as assisted; final outcome remains readable', () async {
    final id = await newCollection(['ticket', 'crowded']);
    final api = FakeTalkApi()
      ..answers.add(const TalkTurn(
          reply: 'Explain the problem.',
          target: 'ticket',
          interaction: 'speak',
          speakingPrompt: 'Ask for what you need.'));
    final (c, talk) = await started(id, api);
    expect(c.read(talkProvider(id)).hintAvailable, isTrue);
    talk.showHint();
    api.answers.add(const TalkTurn(reply: 'You made it home!', target: 'ticket', interaction: 'complete'));
    await talk.send('I need a ticket for the crowded bus');
    final s = c.read(talkProvider(id));
    expect(s.complete, isTrue);
    expect(s.status, TalkStatus.talking);
    expect(s.usedCount, 2);
    expect(s.messages.last.text, 'You made it home!');
    expect(api.calls.last.history.last.isChoice, isFalse);
    await talk.send('another reply');
    expect(api.calls.length, 2);
    final outcomes = scoreTalk(s.words.map((w) => w.word).toList(),
        used: s.words.map((w) => w.word.rowId).toSet(), hinted: s.hinted);
    expect(outcomes.values, containsAll([WordOutcome.hinted, WordOutcome.clean]));
  });

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

    test('scoreTalk: used clean, used after its hint hinted, never used unused (AC-22)', () {
      final out = scoreTalk(words, used: {'a', 'b'}, hinted: {'b', 'c'});
      expect(out[words[0]], WordOutcome.clean);
      expect(out[words[1]], WordOutcome.hinted);
      expect(out[words[2]], WordOutcome.unused);
    });

    test('scoreTalk: a wrong answer is a mistake, even after a hint (self-check-cards AC-01)', () {
      final out = scoreTalk(words, used: {'a', 'b'}, hinted: {'b'}, missed: {'a', 'b', 'c'});
      expect(out[words[0]], WordOutcome.missed);
      expect(out[words[1]], WordOutcome.missed);
      expect(out[words[2]], WordOutcome.unused, reason: 'never used stays unused');
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

    test('talk-mission: the scene is only the topic, never the mnemonic story or a film dialogue', () async {
      final id = await newCollection(['crowded', 'ticket', 'gate'], name: 'Trip');
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
      expect(api.calls.single.scene, 'Trip');
    });

    test('talk-mission: the talk keeps the mission\'s words, sends its brief as the scene and draws its picture',
        () async {
      final id = await newCollection(['crowded', 'ticket', 'gate', 'luggage', 'delay'], name: 'Airport');
      const mission = TalkMission(
        title: 'The Lost Bag',
        role: 'You are a passenger.',
        goal: 'Get your bag back.',
        brief: 'A sleepy clerk knows the bag went to Rome.',
        words: ['Ticket', 'luggage', 'unknown'],
        picture: 'A sleepy clerk at a counter.',
      );
      final api = FakeTalkApi()
        ..answers.addAll([
          const TalkTurn(reply: 'Next! What is the problem?', target: 'ticket', mission: mission),
          const TalkTurn(reply: 'Hm. Do you have proof?', target: 'ticket'),
        ]);
      final pictures = FakeTalkPicture()..bytes = Uint8List.fromList([1, 2, 3]);
      final (c, talk) = await started(id, api, pictures: pictures);
      var s = c.read(talkProvider(id));
      expect([for (final w in s.words) w.word.word], ['ticket', 'luggage']);
      expect(s.mission?.title, 'The Lost Bag');
      expect(s.target, 'ticket');
      await pumpEventQueue();
      s = c.read(talkProvider(id));
      expect(pictures.prompts, ['A sleepy clerk at a counter.']);
      expect(s.picture, [1, 2, 3]);
      expect(s.pictureLoading, isFalse);

      await talk.send('I lost my bag');
      expect(api.calls.last.kind, 'reply');
      expect(api.calls.last.scene, contains('A sleepy clerk knows the bag went to Rome.'));
      expect(api.calls.last.scene, contains(mission.goal));
      expect(api.calls.last.scene, contains(mission.picture));
      expect([for (final w in api.calls.last.words) w.word], ['ticket', 'luggage']);
    });

    test('talk-mission: a picture that fails leaves the talk without one', () async {
      final id = await newCollection(['crowded', 'ticket']);
      const mission =
          TalkMission(title: 'T', role: 'You are a cook.', goal: 'G', brief: 'B', words: ['ticket'], picture: 'P');
      final api = FakeTalkApi()..answers.add(const TalkTurn(reply: 'Hi?', target: 'ticket', mission: mission));
      final (c, _) = await started(id, api, pictures: FakeTalkPicture());
      expect(c.read(talkProvider(id)).pictureLoading, isTrue);
      await pumpEventQueue();
      expect(c.read(talkProvider(id)).picture, isNull);
      expect(c.read(talkProvider(id)).pictureLoading, isFalse);
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
      expect({
        for (final w in s.words)
          if (w.used) w.word.word
      }, {
        'crowded'
      });
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
      expect(boxes.containsKey('r2'), isFalse, reason: 'hinted, never rated: a new word keeps no box (AC-09)');
      expect(boxes['r3']!.box, 3); // never used: box and next review kept
      expect(boxes['r3']!.dueAt, DateTime(2026, 10, 23));

      // A second Done writes nothing more.
      await talk.finish();
      expect((await store.byId(id))!.boxes.length, 2);
    });

    test('talk quiz: 5 words in the talk open a quick check; its answers score the words', () async {
      final id = await newCollection(['shore', 'tide', 'fog', 'gale', 'harbour']);
      final api = FakeTalkApi()
        ..answers.addAll([
          const TalkTurn(reply: 'The fog hides the shore and the tide.', target: 'shore'),
          const TalkTurn(reply: 'A gale is coming to the harbour!', target: 'tide'),
        ]);
      final (c, talk) = await started(id, api);
      await pumpEventQueue();
      expect(c.read(talkProvider(id)).openQuiz, isNull, reason: 'only 3 words so far');
      await talk.send('What now?');
      await pumpEventQueue();
      var s = c.read(talkProvider(id));
      final quiz = s.openQuiz!.quiz!;
      expect(s.openQuiz!.at, 3, reason: 'after the AI line that brought the 5th word');
      expect([for (final i in quiz.items) i.kind], [
        TalkQuizKind.translate,
        TalkQuizKind.fillGap,
        TalkQuizKind.pickAnswer,
        TalkQuizKind.matchDefinitions,
      ]);
      expect(s.spokenQuizItem?.word.word, 'shore');

      talk.answerQuiz('shore'); // right
      talk.nextQuiz();
      talk.answerQuiz('wave'); // wrong: tide
      talk.nextQuiz();
      talk.answerQuiz('fog'); // right
      talk.nextQuiz();
      final match = c.read(talkProvider(id)).openQuiz!.quiz!.current;
      for (final w in match.words) {
        talk.matchQuiz(w.rowId, w.rowId);
      }
      talk.nextQuiz();
      s = c.read(talkProvider(id));
      expect(s.openQuiz, isNull, reason: 'back to the talk');
      expect(s.quizzes.single.quiz!.closed, isTrue);
      expect(s.quizzes.single.quiz!.wrongRows, {'r2'});

      await talk.finish();
      final states = {for (final m in c.read(lastSessionResultProvider)!.moves) m.word: m.state};
      expect(states['shore'], WordState.knownWell, reason: 'right in the quiz counts as a use');
      expect(states['tide'], WordState.isNew, reason: 'wrong in the quiz counts as a miss');
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
        ratings: {c.words[1]: (rating: SelfRating.hard, side: 'uk')},
        kind: SessionKind.exercises,
        now: now,
        groupIndex: 1,
        groupCount: 3,
        pages: 7,
      );
      expect(result.written, isTrue);
      expect(result.collectionId, id);
      expect(result.moves.map((m) => m.state), [WordState.knownWell, WordState.isNew]);
      expect(result.moves.map((m) => m.rating), [null, SelfRating.hard]);
      expect(result.groupIndex, 1);
      expect(result.groupCount, 3);
      expect(result.pages, 7);
      final stored = (await store.byId(id))!.boxes;
      expect(stored.length, 2);
      expect(stored.firstWhere((b) => b.rowId == c.words[1].rowId).lastCheckSide, 'uk');
    });

    test('a flagged word without a rating keeps its box (self-check-cards AC-09)', () async {
      final id = await newCollection(['walk']);
      final c = (await store.byId(id))!;
      final result = await finishSession(
        store: store,
        collectionId: id,
        outcomes: {c.words[0]: WordOutcome.missed},
        kind: SessionKind.exercises,
        now: now,
      );
      expect(result.written, isTrue);
      expect(result.moves.single.state, WordState.isNew);
      expect(result.moves.single.rating, isNull);
      expect((await store.byId(id))!.boxes, isEmpty);
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
