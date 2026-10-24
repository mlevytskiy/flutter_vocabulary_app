import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:flutter_vocabulary_app/config/vocab_api_config.dart';
import 'package:flutter_vocabulary_app/core/services/openai_voice_service.dart';

/// openai-voice (owner, 2026-10-24; AC-31): the app's side of the Worker's
/// POST /learn/speech.
void main() {
  final mp3 = Uint8List.fromList([0x49, 0x44, 0x33, 1, 2, 3]);

  test('posts text and voice with the app secret and returns the mp3 bytes', () async {
    late http.Request sent;
    final service = OpenAiVoiceService(client: MockClient((r) async {
      sent = r;
      return http.Response.bytes(mp3, 200, headers: {'content-type': 'audio/mpeg'});
    }));
    final bytes = await service.synthesize('Hello there.', 'nova');
    expect(bytes, mp3);
    expect(sent.method, 'POST');
    expect(sent.url.toString(), '${VocabApiConfig.baseUrl}/learn/speech');
    expect(sent.headers['x-app-secret'], VocabApiConfig.appSecret);
    expect(jsonDecode(sent.body), {'text': 'Hello there.', 'voice': 'nova'});
  });

  test('a line spoken lately comes from memory: no second call (owner, 2026-10-24)', () async {
    var calls = 0;
    final service = OpenAiVoiceService(client: MockClient((r) async {
      calls++;
      return http.Response.bytes(mp3, 200, headers: {'content-type': 'audio/mpeg'});
    }));
    expect(await service.synthesize('Hello there.', 'nova'), mp3);
    expect(await service.synthesize('Hello there.', 'nova'), mp3);
    expect(calls, 1);
    await service.synthesize('Hello there.', 'coral');
    expect(calls, 2, reason: 'another voice is another recording');
  });

  test('a failed call is not remembered', () async {
    var calls = 0;
    final service = OpenAiVoiceService(client: MockClient((r) async {
      calls++;
      return calls == 1 ? http.Response('{"code":"speech_failed"}', 502) : http.Response.bytes(mp3, 200);
    }));
    await expectLater(service.synthesize('Hi', 'coral'), throwsA(isA<OpenAiVoiceException>()));
    expect(await service.synthesize('Hi', 'coral'), mp3);
    expect(calls, 2);
  });

  Future<OpenAiVoiceError> errorOf(OpenAiVoiceService service) async {
    try {
      await service.synthesize('Hi', 'coral');
    } on OpenAiVoiceException catch (e) {
      return e.error;
    }
    fail('no exception');
  }

  OpenAiVoiceService answering(int status, Map<String, String> body) =>
      OpenAiVoiceService(client: MockClient((_) async => http.Response(jsonEncode(body), status)));

  test('429 day_limit -> dayLimit', () async {
    expect(await errorOf(answering(429, {'code': 'day_limit'})), OpenAiVoiceError.dayLimit);
  });

  test('503 speech_unavailable -> unavailable', () async {
    expect(await errorOf(answering(503, {'code': 'speech_unavailable'})), OpenAiVoiceError.unavailable);
  });

  test('502 and an empty 200 -> failed', () async {
    expect(await errorOf(answering(502, {'code': 'speech_failed'})), OpenAiVoiceError.failed);
    final empty = OpenAiVoiceService(client: MockClient((_) async => http.Response.bytes(const [], 200)));
    expect(await errorOf(empty), OpenAiVoiceError.failed);
  });

  test('no answer in time or no connection -> network', () async {
    final slow = OpenAiVoiceService(
      client: MockClient((_) => Completer<http.Response>().future),
      timeout: const Duration(milliseconds: 20),
    );
    expect(await errorOf(slow), OpenAiVoiceError.network);
    final offline = OpenAiVoiceService(client: MockClient((_) async => throw http.ClientException('offline')));
    expect(await errorOf(offline), OpenAiVoiceError.network);
    expect(OpenAiVoiceService.lineTimeout, const Duration(seconds: 20));
  });

  group('splitForSpeech', () {
    test('a short text is one chunk', () {
      expect(splitForSpeech('Hello. How are you?'), ['Hello. How are you?']);
    });

    test('a long text splits on sentence ends into chunks of at most 1200', () {
      final sentence = '${'word ' * 30}end.'; // 154 characters
      final text = List.filled(20, sentence).join(' ');
      final chunks = splitForSpeech(text);
      expect(chunks.length, greaterThan(1));
      for (final c in chunks) {
        expect(c.length, lessThanOrEqualTo(1200));
        expect(c.endsWith('end.'), isTrue);
      }
      expect(chunks.join(' '), text);
    });

    test('a sentence longer than 1200 splits on spaces', () {
      final text = 'word ' * 400;
      final chunks = splitForSpeech(text.trim());
      expect(chunks.every((c) => c.length <= 1200), isTrue);
      expect(chunks.join(' '), text.trim());
    });
  });
}
