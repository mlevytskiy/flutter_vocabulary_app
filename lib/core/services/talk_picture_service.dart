import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../config/vocab_api_config.dart';

/// The opening picture of a Talk mission (talk-mission, owner 2026-10-24):
/// the Worker's `POST /learn/talk/picture`, behind the app secret, 20 a day.
/// Any failure gives null: the talk goes on without its picture.
class TalkPictureService {
  /// The Worker gives up on the picture at 40 s, so its error arrives first.
  static const pictureTimeout = Duration(seconds: 45);

  final http.Client _client;
  final Duration _timeout;

  TalkPictureService({http.Client? client, Duration timeout = TalkPictureService.pictureTimeout})
      : _client = client ?? http.Client(),
        _timeout = timeout;

  /// The picture for [prompt] (the mission's), or null.
  Future<Uint8List?> draw(String prompt) async {
    try {
      final response = await _client
          .post(
            Uri.parse('${VocabApiConfig.baseUrl}/learn/talk/picture'),
            headers: {
              'content-type': 'application/json; charset=utf-8',
              'x-app-secret': VocabApiConfig.appSecret,
            },
            body: jsonEncode({'prompt': prompt}),
          )
          .timeout(_timeout);
      final type = response.headers['content-type'] ?? '';
      if (response.statusCode == 200 && type.startsWith('image/') && response.bodyBytes.isNotEmpty) {
        return response.bodyBytes;
      }
      debugPrint('talk picture: status ${response.statusCode}');
    } catch (e) {
      debugPrint('talk picture: $e');
    }
    return null;
  }
}
