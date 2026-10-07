import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_vocabulary_app/core/models/offered_ai.dart';
import 'package:flutter_vocabulary_app/core/models/word_group.dart';
import 'package:flutter_vocabulary_app/core/providers.dart';
import 'package:flutter_vocabulary_app/core/services/story_api_service.dart';
import 'package:flutter_vocabulary_app/core/story/word_grouping.dart';

/// mnemonic-story T12: the app side of the Worker's story routes (T7, T9) --
/// answers and refusal codes become typed results (AC-12, AC-13, AC-19).
void main() {
  late List<http.Request> requests;

  StoryApiService answering(int status, Object body,
      {Map<String, String> headers = const {'content-type': 'application/json'}}) {
    requests = [];
    return StoryApiService(
      client: MockClient((request) async {
        requests.add(request);
        return http.Response.bytes(
          body is Uint8List ? body : utf8.encode(jsonEncode(body)),
          status,
          headers: headers,
        );
      }),
    );
  }

  const modelsBody = {
    'pricesAsOf': '2026-10-07',
    'defaults': {
      'story': 'claude-sonnet-5-5',
      'prompt': 'claude-sonnet-5-5',
      'picture': 'grok-imagine-image',
    },
    'models': [
      {
        'id': 'claude-sonnet-5-5',
        'name': 'Sonnet 5.5',
        'provider': 'anthropic',
        'role': 'text',
        'inputUsdPerMTok': 2,
        'outputUsdPerMTok': 10,
        'estimate15Usd': 0.008,
      },
      {
        'id': 'grok-imagine-image',
        'name': 'Grok Imagine',
        'provider': 'xai',
        'role': 'picture',
        'usdPerPicture': 0.02,
      },
      {
        'id': 'marketing-studio/image/sunburst',
        'name': 'Higgsfield Marketing Studio',
        'provider': 'higgsfield',
        'role': 'picture',
        'usdPerPicture': 0.013,
        'approx': true,
      },
    ],
  };

  group('offeredAis', () {
    test('GET /story/models with the secret, parsed into the list', () async {
      final list = await answering(200, modelsBody).offeredAis();

      expect(requests.single.method, 'GET');
      expect(requests.single.url.path, endsWith('/story/models'));
      expect(requests.single.headers.containsKey('x-app-secret'), isTrue);
      expect(list.pricesAsOf, '2026-10-07');
      expect(list.defaults.story, 'claude-sonnet-5-5');
      expect(list.defaults.picture, 'grok-imagine-image');
      expect(list.models, hasLength(3));
      final sonnet = list.byId('claude-sonnet-5-5')!;
      expect(sonnet.isText, isTrue);
      expect(sonnet.estimate15Usd, 0.008);
      expect(sonnet.inputUsdPerMTok, 2);
      final higgs = list.byId('marketing-studio/image/sunburst')!;
      expect(higgs.isPicture, isTrue);
      expect(higgs.approx, isTrue);
      expect(list.textModels.map((m) => m.id), ['claude-sonnet-5-5']);
      expect(list.pictureModels.map((m) => m.id),
          ['grok-imagine-image', 'marketing-studio/image/sunburst']);
    });

    test('survives a JSON round trip, for the cache', () async {
      final list = await answering(200, modelsBody).offeredAis();
      final again = OfferedAiList.fromJson(
          jsonDecode(jsonEncode(list.toJson())) as Map<String, dynamic>);
      expect(again.pricesAsOf, list.pricesAsOf);
      expect(again.models.map((m) => m.id), list.models.map((m) => m.id));
      expect(again.byId('grok-imagine-image')!.usdPerPicture, 0.02);
    });

    test('a failed or odd answer throws a typed error', () async {
      await expectLater(
        answering(500, {'error': 'x'}).offeredAis(),
        throwsA(isA<StoryApiException>()),
      );
      await expectLater(
        answering(200, {'nope': 1}).offeredAis(),
        throwsA(isA<StoryApiException>()
            .having((e) => e.error, 'error', StoryApiError.unexpected)),
      );
    });

    test('a network error is a typed error', () async {
      final service = StoryApiService(
          client: MockClient((_) async => throw http.ClientException('down')));
      await expectLater(
        service.offeredAis(),
        throwsA(isA<StoryApiException>()
            .having((e) => e.error, 'error', StoryApiError.network)),
      );
    });

    test('no answer within the deadline is a timeout', () async {
      final service = StoryApiService(
        client: MockClient((_) => Completer<http.Response>().future),
        timeout: const Duration(milliseconds: 20),
      );
      await expectLater(
        service.offeredAis(),
        throwsA(isA<StoryApiException>()
            .having((e) => e.error, 'error', StoryApiError.timeout)),
      );
    });
  });

  group('group', () {
    test('POSTs the words and kept groups, returns the split', () async {
      final keep = [
        WordGroup()
          ..id = 'g1'
          ..name = 'Kitchen'
          ..rowIds = ['r1', 'r2'],
      ];
      final split = await answering(200, {
        'groups': [
          {'id': 'g1', 'name': 'Kitchen', 'rowIds': ['r1', 'r2', 'r3']},
          {'name': 'Travel', 'rowIds': ['r4']},
        ],
      }).group(const [GroupingWord('r3', 'spoon'), GroupingWord('r4', 'ticket')], keep);

      expect(requests.single.method, 'POST');
      expect(requests.single.url.path, endsWith('/story/grouping'));
      expect(requests.single.headers['x-app-secret'], isNotEmpty);
      expect(jsonDecode(requests.single.body), {
        'words': [
          {'rowId': 'r3', 'word': 'spoon'},
          {'rowId': 'r4', 'word': 'ticket'},
        ],
        'keep': [
          {'id': 'g1', 'name': 'Kitchen', 'rowIds': ['r1', 'r2']},
        ],
      });
      expect(split, hasLength(2));
      expect(split.first.id, 'g1');
      expect(split.last.id, isNull);
      expect(split.last.rowIds, ['r4']);
    });

    test('502 grouping_failed is a typed error', () async {
      await expectLater(
        answering(502, {'error': 'Could not group the words', 'code': 'grouping_failed'})
            .group(const [GroupingWord('r1', 'a')], const []),
        throwsA(isA<StoryApiException>()
            .having((e) => e.error, 'error', StoryApiError.groupingFailed)),
      );
    });

    test('429 is rateLimited', () async {
      await expectLater(
        answering(429, {'error': 'slow down'}).group(const [GroupingWord('r1', 'a')], const []),
        throwsA(isA<StoryApiException>()
            .having((e) => e.error, 'error', StoryApiError.rateLimited)),
      );
    });
  });

  group('startRun', () {
    Future<StoryActionResult> start(StoryApiService s) => s.startRun(
          runId: 'run-1',
          words: const ['spoon', 'fork'],
          storyModel: 'claude-sonnet-5-5',
          promptModel: 'claude-sonnet-5-5',
          pictureModel: 'grok-imagine-image',
        );

    test('POSTs the run and maps 200 to started', () async {
      final result = await start(answering(200, {'started': true}));

      expect(requests.single.method, 'POST');
      expect(requests.single.url.path, endsWith('/story/runs'));
      expect(jsonDecode(requests.single.body), {
        'runId': 'run-1',
        'words': ['spoon', 'fork'],
        'storyModel': 'claude-sonnet-5-5',
        'promptModel': 'claude-sonnet-5-5',
        'pictureModel': 'grok-imagine-image',
      });
      expect(result, isA<StoryStarted>());
    });

    test('422 not_offered carries the model', () async {
      final result = await start(answering(
          422, {'error': 'x', 'code': 'not_offered', 'model': 'gpt-old'}));
      expect(result, isA<StoryRefused>()
          .having((r) => r.reason, 'reason', StoryRefusal.notOffered)
          .having((r) => r.model, 'model', 'gpt-old'));
    });

    test('429 day_limit is dayLimit (AC-19)', () async {
      final result =
          await start(answering(429, {'error': 'x', 'code': 'day_limit'}));
      expect(result, isA<StoryRefused>()
          .having((r) => r.reason, 'reason', StoryRefusal.dayLimit));
    });

    test('429 without the code is rateLimited', () async {
      final result = await start(answering(429, {'error': 'Too many requests'}));
      expect(result, isA<StoryRefused>()
          .having((r) => r.reason, 'reason', StoryRefusal.rateLimited));
    });

    test('503 no_storage is unavailable; 400 and 500 throw', () async {
      expect(
        await start(answering(503, {'error': 'x', 'code': 'no_storage'})),
        isA<StoryRefused>()
            .having((r) => r.reason, 'reason', StoryRefusal.unavailable),
      );
      await expectLater(start(answering(400, {'error': 'bad'})),
          throwsA(isA<StoryApiException>()));
      await expectLater(start(answering(500, {'error': 'bad'})),
          throwsA(isA<StoryApiException>()));
    });
  });

  group('status', () {
    test('GET with the ids, steps parsed', () async {
      final runs = await answering(200, {
        'runs': [
          {
            'runId': 'a',
            'words': ['spoon'],
            'storyModel': 'claude-sonnet-5-5',
            'promptModel': 'claude-sonnet-5-5',
            'pictureModel': 'grok-imagine-image',
            'createdAt': '2026-10-07T10:00:00.000Z',
            'steps': [
              {
                'role': 'story', 'attempt': 1, 'modelId': 'claude-sonnet-5-5',
                'outcome': 'done', 'text': 'Once...', 'missedWords': [],
                'pictureKey': null, 'priceUsd': 0.004, 'priceEstimated': false,
                'ms': 3200, 'startedAt': '2026-10-07T10:00:01.000Z',
                'finishedAt': '2026-10-07T10:00:04.000Z',
              },
              {
                'role': 'picture', 'attempt': 1, 'modelId': 'grok-imagine-image',
                'outcome': 'running', 'text': null, 'missedWords': null,
                'pictureKey': null, 'priceUsd': null, 'priceEstimated': false,
                'ms': null, 'startedAt': '2026-10-07T10:00:05.000Z',
                'finishedAt': null,
              },
            ],
          },
        ],
      }).status(['a', 'b']);

      expect(requests.single.method, 'GET');
      expect(requests.single.url.path, endsWith('/story/runs'));
      expect(requests.single.url.queryParameters['ids'], 'a,b');
      expect(runs, hasLength(1));
      expect(runs.single.runId, 'a');
      expect(runs.single.createdAt, DateTime.utc(2026, 10, 7, 10));
      final story = runs.single.steps.first;
      expect(story.role, 'story');
      expect(story.outcome, 'done');
      expect(story.text, 'Once...');
      expect(story.missedWords, isEmpty);
      expect(story.priceUsd, 0.004);
      expect(story.ms, 3200);
      final picture = runs.single.steps.last;
      expect(picture.outcome, 'running');
      expect(picture.priceUsd, isNull);
      expect(picture.finishedAt, isNull);
    });

    test('no ids asks nothing', () async {
      final service = answering(200, {'runs': []});
      expect(await service.status(const []), isEmpty);
      expect(requests, isEmpty);
    });

    test('a failed answer throws', () async {
      await expectLater(answering(400, {'error': 'x'}).status(['a']),
          throwsA(isA<StoryApiException>()));
    });
  });

  group('redo', () {
    test('picture: POSTs the step and model, started carries the attempt', () async {
      final result = await answering(200, {'started': true, 'attempt': 2}).redo(
          runId: 'a', step: 'picture', pictureModel: 'grok-imagine-image');

      expect(requests.single.method, 'POST');
      expect(requests.single.url.path, endsWith('/story/runs/redo'));
      expect(jsonDecode(requests.single.body),
          {'runId': 'a', 'step': 'picture', 'pictureModel': 'grok-imagine-image'});
      expect(result, isA<StoryStarted>().having((r) => r.attempt, 'attempt', 2));
    });

    test('prompt: no model in the body', () async {
      await answering(200, {'started': true}).redo(runId: 'a', step: 'prompt');
      expect(jsonDecode(requests.single.body), {'runId': 'a', 'step': 'prompt'});
    });

    test('refusals: 404, 409, 422, 429', () async {
      Future<StoryActionResult> redo(int status, Map<String, Object> body) =>
          answering(status, body).redo(runId: 'a', step: 'picture');

      expect(await redo(404, {'error': 'x', 'code': 'unknown_run'}),
          isA<StoryRefused>().having((r) => r.reason, 'reason', StoryRefusal.unknownRun));
      expect(await redo(409, {'error': 'x', 'code': 'not_failed'}),
          isA<StoryRefused>().having((r) => r.reason, 'reason', StoryRefusal.notFailed));
      expect(await redo(422, {'error': 'x', 'code': 'not_offered', 'model': 'm'}),
          isA<StoryRefused>().having((r) => r.reason, 'reason', StoryRefusal.notOffered));
      expect(await redo(429, {'error': 'x', 'code': 'day_limit'}),
          isA<StoryRefused>().having((r) => r.reason, 'reason', StoryRefusal.dayLimit));
    });
  });

  group('picture', () {
    test('returns the bytes', () async {
      final bytes = Uint8List.fromList([1, 2, 3]);
      final got = await answering(200, bytes,
          headers: {'content-type': 'image/png'}).picture('a', 2);
      expect(requests.single.method, 'GET');
      expect(requests.single.url.path, endsWith('/story/runs/a/pictures/2'));
      expect(requests.single.headers.containsKey('x-app-secret'), isTrue);
      expect(got, bytes);
    });

    test('404 (collected or too old) is null; 503 throws', () async {
      expect(await answering(404, {'error': 'Not found'}).picture('a', 1), isNull);
      await expectLater(answering(503, {'error': 'x'}).picture('a', 1),
          throwsA(isA<StoryApiException>()));
    });
  });

  group('offeredAisProvider (AC-13 fallback)', () {
    ProviderContainer containerWith(StoryApiService service) {
      final c = ProviderContainer(
          overrides: [storyApiServiceProvider.overrideWithValue(service)]);
      addTearDown(c.dispose);
      return c;
    }

    StoryApiService failing() => StoryApiService(
        client: MockClient((_) async => throw http.ClientException('down')));

    test('a fetched list is used and cached', () async {
      SharedPreferences.setMockInitialValues({});
      final c = containerWith(answering(200, modelsBody));
      final list = await c.read(offeredAisProvider.future);
      expect(list.models, hasLength(3));
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(OfferedAiCache.key), isNotNull);
    });

    test('when the fetch fails, the cached list is used', () async {
      SharedPreferences.setMockInitialValues({});
      await containerWith(answering(200, modelsBody))
          .read(offeredAisProvider.future);

      final list =
          await containerWith(failing()).read(offeredAisProvider.future);
      expect(list.models.map((m) => m.id),
          ['claude-sonnet-5-5', 'grok-imagine-image', 'marketing-studio/image/sunburst']);
    });

    test('with no cache either, the built-in defaults are used', () async {
      SharedPreferences.setMockInitialValues({});
      final list =
          await containerWith(failing()).read(offeredAisProvider.future);
      expect(list.defaults.story, OfferedAiList.fallback.defaults.story);
      expect(list.byId(list.defaults.story), isNotNull);
      expect(list.byId(list.defaults.picture), isNotNull);
    });
  });

  group('aiChoiceProvider (AC-12, AC-13)', () {
    const offered = OfferedAiList(
      pricesAsOf: '2026-10-07',
      defaults: AiChoice(
          story: 'claude-sonnet-5-5',
          prompt: 'claude-sonnet-5-5',
          picture: 'grok-imagine-image'),
      models: [
        OfferedAi(id: 'claude-sonnet-5-5', name: 'Sonnet 5.5', provider: 'anthropic', role: 'text'),
        OfferedAi(id: 'claude-opus-5-5', name: 'Opus 5.5', provider: 'anthropic', role: 'text'),
        OfferedAi(id: 'grok-imagine-image', name: 'Grok Imagine', provider: 'xai', role: 'picture'),
      ],
    );

    test('nothing stored resolves to the defaults', () async {
      SharedPreferences.setMockInitialValues({});
      final c = ProviderContainer();
      addTearDown(c.dispose);
      await c.read(aiChoiceProvider.notifier).loaded;
      final r = resolveAiChoice(c.read(aiChoiceProvider), offered);
      expect(r.choice, offered.defaults);
      expect(r.unavailable, isEmpty);
    });

    test('a choice is kept after a restart', () async {
      SharedPreferences.setMockInitialValues({});
      final first = ProviderContainer();
      await first.read(aiChoiceProvider.notifier).loaded;
      await first.read(aiChoiceProvider.notifier).set(AiRole.story, offered.byId('claude-opus-5-5')!);
      first.dispose();

      final second = ProviderContainer();
      addTearDown(second.dispose);
      await second.read(aiChoiceProvider.notifier).loaded;
      final r = resolveAiChoice(second.read(aiChoiceProvider), offered);
      expect(r.choice.story, 'claude-opus-5-5');
      expect(r.choice.prompt, 'claude-sonnet-5-5');
    });

    test('an AI no longer offered falls back to the default and is named', () async {
      SharedPreferences.setMockInitialValues({
        'story_ai_picture': 'old-picture-ai',
        'story_ai_picture_name': 'Old Picture AI',
        'story_ai_prompt': 'claude-opus-5-5',
      });
      final c = ProviderContainer();
      addTearDown(c.dispose);
      await c.read(aiChoiceProvider.notifier).loaded;
      final r = resolveAiChoice(c.read(aiChoiceProvider), offered);
      expect(r.choice.picture, 'grok-imagine-image');
      expect(r.choice.prompt, 'claude-opus-5-5');
      expect(r.unavailable, {AiRole.picture: 'Old Picture AI'});
    });

    test('an id offered for the other role is not offered for this one', () async {
      SharedPreferences.setMockInitialValues({'story_ai_story': 'grok-imagine-image'});
      final c = ProviderContainer();
      addTearDown(c.dispose);
      await c.read(aiChoiceProvider.notifier).loaded;
      final r = resolveAiChoice(c.read(aiChoiceProvider), offered);
      expect(r.choice.story, 'claude-sonnet-5-5');
      expect(r.unavailable.keys, [AiRole.story]);
    });
  });
}
