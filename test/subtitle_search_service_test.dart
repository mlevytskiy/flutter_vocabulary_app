import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:flutter_vocabulary_app/config/vocab_api_config.dart';
import 'package:flutter_vocabulary_app/core/services/subtitle_search_service.dart';

/// Finding subtitle files by name through the Worker (GET /subtitles/search,
/// POST /subtitles/file).
void main() {
  late http.Request sent;

  SubtitleSearchService answering(int status, Object body) => SubtitleSearchService(
        client: MockClient((request) async {
          sent = request;
          return http.Response.bytes(utf8.encode(body is String ? body : jsonEncode(body)), status,
              headers: {'content-type': 'application/json; charset=utf-8'});
        }),
      );

  Future<SubtitleSearchError> failureOf(Future<Object?> call) async {
    try {
      await call;
    } on SubtitleSearchException catch (e) {
      return e.error;
    }
    fail('expected a SubtitleSearchException');
  }

  const episode = {
    'fileId': 12, 'title': 'The Storm', 'year': 2025, 'show': 'Harbour Lights', 'season': 1, 'episode': 4,
    'release': 'Release.12', 'downloads': 1012, 'hearingImpaired': true,
  };
  const film = {
    'fileId': 11, 'title': 'Harbour Lights', 'year': 2024, 'show': null, 'season': null, 'episode': null,
    'release': 'Release.11', 'downloads': 1011, 'hearingImpaired': false,
  };

  test('search sends the name with the app secret and reads the results', () async {
    final results = await answering(200, {'results': [film, episode]}).search(' Harbour Lights ');
    expect(sent.method, 'GET');
    expect(sent.url.toString(), '${VocabApiConfig.baseUrl}/subtitles/search?query=Harbour+Lights');
    expect(sent.headers['x-app-secret'], VocabApiConfig.appSecret);
    expect(results.map((r) => r.label), ['Harbour Lights (2024)', 'Harbour Lights · S01E04 · The Storm']);
    expect(results.last.hearingImpaired, isTrue);
    expect(results.first.fileId, 11);
  });

  test('download posts the file id and returns its name and bytes', () async {
    final file = await answering(200, {'fileName': 'Release.11.srt', 'text': 'Привіт harbour'}).download(11);
    expect(sent.method, 'POST');
    expect(jsonDecode(sent.body), {'fileId': 11});
    expect(file.fileName, 'Release.11.srt');
    expect(utf8.decode(file.bytes), 'Привіт harbour');
  });

  test('each failure has its own kind', () async {
    expect(await failureOf(answering(429, {'code': 'download_limit'}).download(1)), SubtitleSearchError.downloadLimit);
    expect(await failureOf(answering(413, {'code': 'too_large'}).download(1)), SubtitleSearchError.tooLarge);
    expect(await failureOf(answering(404, {'code': 'not_found'}).download(1)), SubtitleSearchError.notFound);
    expect(await failureOf(answering(502, {'code': 'x'}).search('fog')), SubtitleSearchError.unavailable);
    expect(await failureOf(answering(200, 'not json').search('fog')), SubtitleSearchError.unavailable);
    final offline = SubtitleSearchService(client: MockClient((_) async => throw const SocketException('offline')));
    expect(await failureOf(offline.search('fog')), SubtitleSearchError.unavailable);
  });

  test('titles reads films and series with their seasons', () async {
    final titles = await answering(200, {
      'titles': [
        {'featureId': 501, 'title': 'Harbour Lights', 'year': 2024, 'series': false, 'seasons': []},
        {'featureId': 502, 'title': 'Harbour Lights', 'year': null, 'series': true, 'seasons': [{'season': 1, 'episodes': 4}]},
      ],
    }).titles('harbour li');
    expect(sent.url.toString(), '${VocabApiConfig.baseUrl}/subtitles/titles?query=harbour+li');
    expect(titles.map((t) => t.label), ['Harbour Lights (2024)', 'Harbour Lights']);
    expect(titles.last.seasons.single, (season: 1, episodes: 4));
  });

  test('search by a suggested title sends its id and, for a series, the season and episode', () async {
    const film = SubtitleTitle(featureId: 501, title: 'Harbour Lights', series: false);
    const show = SubtitleTitle(featureId: 502, title: 'Harbour Lights', series: true);
    final service = answering(200, {'results': []});
    await service.search('ignored', title: film, season: 1, episode: 2);
    expect(sent.url.queryParameters, {'featureId': '501'});
    await service.search('ignored', title: show, season: 1, episode: 4);
    expect(sent.url.queryParameters, {'featureId': '502', 'series': 'true', 'season': '1', 'episode': '4'});
    await service.search('ignored', title: show);
    expect(sent.url.queryParameters, {'featureId': '502', 'series': 'true'});
  });
}
