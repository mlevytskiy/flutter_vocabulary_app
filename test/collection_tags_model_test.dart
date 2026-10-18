@Tags(['smoke'])
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_vocabulary_app/core/models/session_source.dart';
import 'package:flutter_vocabulary_app/core/models/tag_kind.dart';
import 'package:flutter_vocabulary_app/core/models/tag_library_entry.dart';
import 'package:flutter_vocabulary_app/core/models/word_collection.dart';
import 'package:flutter_vocabulary_app/core/services/collection_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    final saved = HttpOverrides.current;
    HttpOverrides.global = null;
    try {
      await Isar.initializeIsarCore(download: true);
    } finally {
      HttpOverrides.global = saved;
    }
  });

  test('WordCollection JSON round-trips description and typed tags', () {
    final c = WordCollection.create()
      ..description = 'Words from the trip'
      ..originTags = ['Food']
      ..topicTags = ['Travel', 'Cafe'];
    final back = WordCollection.fromJson(c.toJson());
    expect(back.description, 'Words from the trip');
    expect(back.originTags, ['Food']);
    expect(back.topicTags, ['Travel', 'Cafe']);
    final bare = WordCollection.fromJson(WordCollection.create().toJson());
    expect(bare.description, isNull);
    expect(bare.originTags, isEmpty);
    expect(bare.topicTags, isEmpty);
  });

  test('SessionSource JSON and copy carry typed tags, legacy tags stay', () {
    final s = SessionSource()
      ..id = 'a'
      ..tags = ['old']
      ..originTags = ['Film']
      ..topicTags = ['Slang'];
    final back = SessionSource.fromJson(s.toJson());
    expect(back.originTags, ['Film']);
    expect(back.topicTags, ['Slang']);
    expect(back.tags, ['old']);
    final c = s.copy();
    expect(c.originTags, ['Film']);
    expect(c.topicTags, ['Slang']);
    expect(identical(c.originTags, s.originTags), isFalse);
    final json = (SessionSource()..id = 'b').toJson();
    expect(json.containsKey('originTags'), isFalse);
    expect(json.containsKey('topicTags'), isFalse);
  });

  test('TagLibraryEntry: unique (kind, key) rejects a duplicate', () async {
    SharedPreferences.setMockInitialValues({});
    final dir = Directory.systemTemp.createTempSync('collection_tags_model');
    final store = await CollectionStore.open(directory: dir.path);
    final isar = Isar.getInstance('vocab')!;
    TagLibraryEntry e(TagKind k, String key, String text) => TagLibraryEntry()
      ..kind = k
      ..key = key
      ..text = text;
    try {
      await isar.writeTxn(
          () => isar.tagLibraryEntrys.put(e(TagKind.origin, 'food', 'Food')));
      await isar.writeTxn(
          () => isar.tagLibraryEntrys.put(e(TagKind.topic, 'food', 'Food')));
      expect(await isar.tagLibraryEntrys.count(), 2);
      await expectLater(
        isar.writeTxn(
            () => isar.tagLibraryEntrys.put(e(TagKind.origin, 'food', 'FOOD'))),
        throwsA(isA<IsarError>()),
      );
      expect(await isar.tagLibraryEntrys.count(), 2);
    } finally {
      await store.close();
      dir.deleteSync(recursive: true);
    }
  });
}
