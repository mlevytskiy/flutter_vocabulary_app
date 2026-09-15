import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../../config/vocab_api_config.dart';
import '../models/vocab_word.dart';

class VocabPhotoException implements Exception {
  final String message;
  VocabPhotoException(this.message);

  @override
  String toString() => message;
}

class VocabAnalysisResult {
  final List<VocabWord> words;

  /// Time the server spent waiting on the Claude API call, as measured on
  /// the Cloudflare Worker (excludes our own network round-trip time).
  final Duration? aiDuration;

  VocabAnalysisResult({required this.words, required this.aiDuration});
}

class VocabPhotoService {
  Future<VocabAnalysisResult> analyzePhoto(
    Uint8List imageBytes, {
    required String mediaType,
    bool translation = true,
    bool context = false,
    bool withDesc = false,
    bool shortifyDefinition = false,
    int? limit,
  }) async {
    if (VocabApiConfig.appSecret.isEmpty) {
      throw VocabPhotoException(
        'Vocab API secret is not configured. Fill in lib/config/vocab_api_config.dart.',
      );
    }

    final uri = Uri.parse('${VocabApiConfig.baseUrl}/analyze').replace(
      queryParameters: {
        if (context) 'context': 'true',
        if (translation) 'translation': 'true',
        if (withDesc) 'with_desc': 'false',
        if (shortifyDefinition) 'shortify_definishion': 'false',
        if (limit != null) 'limit': '$limit',
      },
    );

    http.Response response;
    try {
      response = await http
          .post(
            uri,
            headers: {
              'content-type': mediaType,
              'x-app-secret': VocabApiConfig.appSecret,
            },
            body: imageBytes,
          )
          // Without a deadline a stalled connection leaves the caller waiting
          // forever behind the loading overlay, with nothing to report.
          .timeout(const Duration(seconds: 60));
    } on TimeoutException {
      throw VocabPhotoException('The request timed out, please try again');
    } catch (e) {
      throw VocabPhotoException('Network error: $e');
    }

    Map<String, dynamic> decoded;
    try {
      decoded = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      throw VocabPhotoException(
        'Unexpected response (status ${response.statusCode})',
      );
    }

    if (response.statusCode != 200) {
      final error = decoded['error'] as String? ?? 'Request failed';
      throw VocabPhotoException(error);
    }

    final words = (decoded['words'] as List<dynamic>? ?? [])
        .map((item) => VocabWord.fromJson(item as Map<String, dynamic>))
        .toList();

    final timings = decoded['timings'] as Map<String, dynamic>?;
    final aiMs = timings?['aiMs'] as int?;

    return VocabAnalysisResult(
      words: words,
      aiDuration: aiMs != null ? Duration(milliseconds: aiMs) : null,
    );
  }
}
