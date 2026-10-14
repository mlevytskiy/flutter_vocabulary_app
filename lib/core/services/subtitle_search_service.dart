import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../config/vocab_api_config.dart';

/// One English subtitle file found by name (the Worker's GET /subtitles/search,
/// from OpenSubtitles).
class SubtitleSearchResult {
  const SubtitleSearchResult({
    required this.fileId,
    required this.title,
    this.year,
    this.show,
    this.season,
    this.episode,
    required this.release,
    required this.downloads,
    required this.hearingImpaired,
    this.imageUrl,
  });

  final int fileId;

  /// The film's or the episode's title.
  final String title;
  final int? year;

  /// The series' name, for an episode.
  final String? show;
  final int? season;
  final int? episode;

  /// The uploader's release name, e.g. "Show.S01E04.1080p.WEB".
  final String release;
  final int downloads;
  final bool hearingImpaired;

  /// The film's poster, or the series' for an episode; may be missing.
  final String? imageUrl;

  /// "Harbour Lights (2024)", or "Harbour Lights · S01E04 · The Storm".
  String get label {
    if (show != null) {
      final s = season?.toString().padLeft(2, '0');
      final e = episode?.toString().padLeft(2, '0');
      final code = s != null && e != null ? 'S${s}E$e' : null;
      return [show!, if (code != null) code, title].join(' · ');
    }
    return year == null ? title : '$title ($year)';
  }

  factory SubtitleSearchResult.fromJson(Map<String, dynamic> json) => SubtitleSearchResult(
        fileId: json['fileId'] as int,
        title: json['title'] as String,
        year: json['year'] as int?,
        show: json['show'] as String?,
        season: json['season'] as int?,
        episode: json['episode'] as int?,
        release: json['release'] as String,
        downloads: json['downloads'] as int,
        hearingImpaired: json['hearingImpaired'] as bool,
        imageUrl: json['imageUrl'] as String?,
      );
}

/// A film or series suggested while the learner types its name (the Worker's
/// GET /subtitles/titles).
class SubtitleTitle {
  const SubtitleTitle({
    required this.featureId,
    required this.title,
    this.year,
    required this.series,
    this.seasons = const [],
    this.imageUrl,
  });

  final int featureId;
  final String title;
  final int? year;
  final bool series;

  /// For a series: each season and how many episodes it has.
  final List<({int season, int episodes})> seasons;

  /// Its small poster; may be missing.
  final String? imageUrl;

  /// "My Brilliant Friend (2018)".
  String get label => year == null ? title : '$title ($year)';

  factory SubtitleTitle.fromJson(Map<String, dynamic> json) => SubtitleTitle(
        featureId: json['featureId'] as int,
        title: json['title'] as String,
        year: json['year'] as int?,
        series: json['series'] as bool,
        seasons: [
          for (final s in json['seasons'] as List<dynamic>)
            (season: (s as Map<String, dynamic>)['season'] as int, episodes: s['episodes'] as int),
        ],
        imageUrl: json['imageUrl'] as String?,
      );
}

/// The ways finding a subtitle file can fail, each with its own message.
enum SubtitleSearchError {
  /// No connection, no answer in time, or OpenSubtitles failing.
  unavailable,

  /// The day's downloads are used up (429).
  downloadLimit,

  /// The file is over 1 MB (413).
  tooLarge,

  /// The file is gone (404).
  notFound,
}

class SubtitleSearchException implements Exception {
  SubtitleSearchException(this.error, this.detail);
  final SubtitleSearchError error;
  final String detail;

  @override
  String toString() => 'SubtitleSearchException(${error.name}): $detail';
}

/// Finds English subtitle files by film or series name and fetches one, through
/// the Worker (GET /subtitles/search, POST /subtitles/file), so the
/// OpenSubtitles key never leaves it.
class SubtitleSearchService {
  static const defaultTimeout = Duration(seconds: 30);

  final http.Client _client;
  final Duration _timeout;

  SubtitleSearchService({http.Client? client, Duration timeout = defaultTimeout})
      : _client = client ?? http.Client(),
        _timeout = timeout;

  Map<String, String> get _headers => {
        'content-type': 'application/json; charset=utf-8',
        'x-app-secret': VocabApiConfig.appSecret,
      };

  /// Films and series whose name starts like [query], for suggestions.
  Future<List<SubtitleTitle>> titles(String query) async {
    final uri = Uri.parse('${VocabApiConfig.baseUrl}/subtitles/titles').replace(queryParameters: {'query': query.trim()});
    final response = await _send(() => _client.get(uri, headers: _headers));
    try {
      final decoded = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      return [
        for (final item in decoded['titles'] as List<dynamic>) SubtitleTitle.fromJson(item as Map<String, dynamic>),
      ];
    } catch (e) {
      throw SubtitleSearchException(SubtitleSearchError.unavailable, 'unexpected answer: $e');
    }
  }

  /// Subtitle files for a suggested [title] — for a series, optionally one
  /// [season] and [episode] — or, without one, for the typed [query].
  Future<List<SubtitleSearchResult>> search(String query, {SubtitleTitle? title, int? season, int? episode}) async {
    final uri = Uri.parse('${VocabApiConfig.baseUrl}/subtitles/search').replace(
      queryParameters: title == null
          ? {'query': query.trim()}
          : {
              'featureId': '${title.featureId}',
              if (title.series) 'series': 'true',
              if (title.series && season != null) 'season': '$season',
              if (title.series && episode != null) 'episode': '$episode',
            },
    );
    final response = await _send(() => _client.get(uri, headers: _headers));
    try {
      final decoded = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      return [
        for (final item in decoded['results'] as List<dynamic>)
          SubtitleSearchResult.fromJson(item as Map<String, dynamic>),
      ];
    } catch (e) {
      throw SubtitleSearchException(SubtitleSearchError.unavailable, 'unexpected answer: $e');
    }
  }

  /// The file's name and bytes, ready to import like a file from the phone.
  Future<({String fileName, Uint8List bytes})> download(int fileId) async {
    final response = await _send(() => _client.post(
          Uri.parse('${VocabApiConfig.baseUrl}/subtitles/file'),
          headers: _headers,
          body: jsonEncode({'fileId': fileId}),
        ));
    try {
      final decoded = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      return (
        fileName: decoded['fileName'] as String,
        bytes: Uint8List.fromList(utf8.encode(decoded['text'] as String)),
      );
    } catch (e) {
      throw SubtitleSearchException(SubtitleSearchError.unavailable, 'unexpected answer: $e');
    }
  }

  Future<http.Response> _send(Future<http.Response> Function() request) async {
    http.Response response;
    try {
      response = await request().timeout(_timeout);
    } on TimeoutException {
      throw SubtitleSearchException(SubtitleSearchError.unavailable, 'no answer within ${_timeout.inSeconds} s');
    } catch (e) {
      throw SubtitleSearchException(SubtitleSearchError.unavailable, 'network error: $e');
    }
    if (response.statusCode == 200) return response;
    debugPrint('subtitle search: status ${response.statusCode} ${response.body}');
    throw SubtitleSearchException(
      switch (response.statusCode) {
        429 => SubtitleSearchError.downloadLimit,
        413 => SubtitleSearchError.tooLarge,
        404 => SubtitleSearchError.notFound,
        _ => SubtitleSearchError.unavailable,
      },
      'status ${response.statusCode}',
    );
  }
}
