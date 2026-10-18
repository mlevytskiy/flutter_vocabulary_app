@Tags(['smoke'])
library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pdf/widgets.dart' as pw;

import 'package:flutter_vocabulary_app/core/models/session_source.dart';
import 'package:flutter_vocabulary_app/core/models/word_collection.dart';
import 'package:flutter_vocabulary_app/core/models/word_pair.dart';
import 'package:flutter_vocabulary_app/core/providers.dart';
import 'package:flutter_vocabulary_app/core/services/collection_publish_service.dart';
import 'package:flutter_vocabulary_app/features/words_table/share_formats.dart';

/// collection-tags AC-26: a collection's description and tags (typed and
/// legacy), and its sources' tags, stay on the phone. They never reach a
/// publish request body or any share file.
const _secrets = [
  'SECRET-DESC-123',
  'SECRET-ORIGIN',
  'SECRET-TOPIC',
  'SECRET-LEGACY',
  'SECRET-SRC',
  'SECRET-SRC-DESC',
];

WordCollection _collection() {
  final source = SessionSource()
    ..id = 'set1'
    ..kind = SourceKind.set
    ..name = 'Unit 3'
    ..url = 'https://quizlet.com/1/unit-3'
    ..description = 'SECRET-SRC-DESC'
    ..tags = ['SECRET-LEGACY']
    ..originTags = ['SECRET-SRC']
    ..topicTags = ['SECRET-SRC'];
  return WordCollection()
    ..name = 'My words'
    ..description = 'SECRET-DESC-123'
    ..originTags = ['SECRET-ORIGIN']
    ..topicTags = ['SECRET-TOPIC']
    ..tags = ['SECRET-LEGACY']
    ..sources = [source];
}

void _expectClean(String text, String where) {
  for (final secret in _secrets) {
    expect(text, isNot(contains(secret)), reason: '$where leaks $secret');
  }
}

void main() {
  final collection = _collection();
  final pairs = [
    WordPair(word: 'claim', translation: 'заява', definition: 'to ask for')
      ..sourceId = 'set1',
    WordPair(word: 'shelf', translation: 'полиця'),
  ];

  test('the publish request body carries no description or tag', () async {
    final requests = <http.Request>[];
    final service = CollectionPublishService(
      client: MockClient((request) async {
        requests.add(request);
        return http.Response.bytes(
          utf8.encode(jsonEncode({
            'id': '35ffe55d-907d-4540-a5bb-5bda856dc6f5',
            'url': 'https://example.workers.dev/s/35ffe55d',
            'expiresAt': '2026-10-21T07:32:30.434Z',
          })),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );

    await service.publish(
      pairs,
      detail: WordDetailMode.both,
      sources: collection.sources,
      title: collection.name,
      publishedId: 'abc',
      editToken: 'tok',
    );

    final body = utf8.decode(requests.single.bodyBytes);
    expect(body, contains('Unit 3'), reason: 'the set is declared');
    _expectClean(body, 'publish body');
    final keys = (jsonDecode(body) as Map<String, dynamic>).keys;
    expect(
        keys,
        everyElement(
            isNot(anyOf('description', 'tags', 'originTags', 'topicTags'))));
  });

  group('share files', () {
    final font = pw.Font.ttf(ByteData.sublistView(
        File('assets/fonts/NotoSans-Regular.ttf').readAsBytesSync()));

    for (final format in ShareFormat.values) {
      for (final detail in WordDetailMode.values) {
        test('${format.title} (${detail.name}) carries no description or tag',
            () async {
          final file = await makeShareFile(format, pairs,
              name: collection.name!, detail: detail, font: () async => font);
          // The PDF is binary: its text streams are compressed, so the
          // check covers the raw bytes (file name and subject too).
          _expectClean(latin1.decode(file.bytes), '${format.title} bytes');
          _expectClean(file.fileName, '${format.title} file name');
          _expectClean(file.subject, '${format.title} subject');
        });
      }
    }
  });
}
