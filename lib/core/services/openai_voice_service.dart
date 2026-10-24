import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../config/vocab_api_config.dart';

/// Who speaks the AI's lines in Talk with AI (openai-voice, owner
/// 2026-10-24; AC-31): OpenAI's natural voice through the Worker, or the
/// phone's text to speech.
enum VoiceSource { openAi, phone }

/// The OpenAI voices, in Learn settings' order (owner, 2026-10-24); the
/// Worker accepts exactly these.
const openAiVoices = ['coral', 'nova', 'sage', 'ash', 'alloy', 'ballad', 'echo', 'fable', 'onyx', 'shimmer', 'verse'];
const defaultOpenAiVoice = 'coral';

/// Why no OpenAI audio came back (AC-31). Each one makes the app speak the
/// line with the phone voice.
enum OpenAiVoiceError { dayLimit, unavailable, failed, network }

class OpenAiVoiceException implements Exception {
  final OpenAiVoiceError error;
  final String message;
  OpenAiVoiceException(this.error, this.message);

  @override
  String toString() => 'OpenAiVoiceException(${error.name}): $message';
}

/// [text] cut for the Worker's 1 to [max] characters (AC-31): whole
/// sentences packed together, a sentence longer than [max] cut on spaces,
/// a word longer than [max] cut hard. Joining the chunks with one space
/// gives the text back when its words were one space apart.
List<String> splitForSpeech(String text, {int max = OpenAiVoiceService.maxChars}) {
  final trimmed = text.trim();
  if (trimmed.length <= max) return [trimmed];
  final pieces = <String>[];
  for (final sentence in trimmed.split(RegExp(r'(?<=[.!?…])\s+'))) {
    if (sentence.length <= max) {
      pieces.add(sentence);
      continue;
    }
    for (final word in sentence.split(RegExp(r'\s+'))) {
      for (var i = 0; i < word.length; i += max) {
        pieces.add(word.substring(i, i + max > word.length ? word.length : i + max));
      }
    }
  }
  final chunks = <String>[];
  var current = '';
  for (final piece in pieces) {
    if (current.isEmpty) {
      current = piece;
    } else if (current.length + 1 + piece.length <= max) {
      current = '$current $piece';
    } else {
      chunks.add(current);
      current = piece;
    }
  }
  if (current.isNotEmpty) chunks.add(current);
  return chunks;
}

/// The app's side of the Worker's speech route `POST /learn/speech`
/// (openai-voice, AC-31; ADR-0009 amendment): one line of text in, the mp3
/// of OpenAI's gpt-4o-mini-tts out. Behind the app secret like every other
/// app-only route. Failures throw [OpenAiVoiceException].
class OpenAiVoiceService {
  /// The Worker gives up on OpenAI at 15 s, so its error arrives first.
  static const lineTimeout = Duration(seconds: 20);

  /// The longest text the Worker takes in one call.
  static const maxChars = 1200;

  final http.Client _client;
  final Duration _timeout;

  OpenAiVoiceService({http.Client? client, Duration timeout = OpenAiVoiceService.lineTimeout})
      : _client = client ?? http.Client(),
        _timeout = timeout;

  /// The mp3 of [text] (1 to [maxChars] characters) spoken by [voice], one
  /// of [openAiVoices]. Takes one of the day's 400 speech calls app-wide.
  Future<Uint8List> synthesize(String text, String voice) async {
    final http.Response response;
    try {
      response = await _client
          .post(
            Uri.parse('${VocabApiConfig.baseUrl}/learn/speech'),
            headers: {
              'content-type': 'application/json; charset=utf-8',
              'x-app-secret': VocabApiConfig.appSecret,
            },
            body: jsonEncode({'text': text, 'voice': voice}),
          )
          .timeout(_timeout);
    } on TimeoutException {
      throw OpenAiVoiceException(OpenAiVoiceError.network, 'no answer within ${_timeout.inSeconds} s');
    } catch (e) {
      throw OpenAiVoiceException(OpenAiVoiceError.network, '$e');
    }
    if (response.statusCode == 200) {
      if (response.bodyBytes.isEmpty) throw OpenAiVoiceException(OpenAiVoiceError.failed, 'no audio');
      return response.bodyBytes;
    }
    Object? code;
    try {
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is Map<String, dynamic>) code = decoded['code'];
    } catch (_) {
      // An unreadable body is handled by its status.
    }
    debugPrint('speech api: status ${response.statusCode} ${code ?? ''}');
    final error = switch ((response.statusCode, code)) {
      (429, 'day_limit') => OpenAiVoiceError.dayLimit,
      (503, _) => OpenAiVoiceError.unavailable,
      _ => OpenAiVoiceError.failed,
    };
    throw OpenAiVoiceException(error, 'status ${response.statusCode}');
  }
}
