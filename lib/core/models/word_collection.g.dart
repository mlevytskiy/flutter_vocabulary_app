// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'word_collection.dart';

// **************************************************************************
// IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types, experimental_member_use

extension GetWordCollectionCollection on Isar {
  IsarCollection<WordCollection> get wordCollections => this.collection();
}

const WordCollectionSchema = CollectionSchema(
  name: r'Session',
  id: 4817823809690647594,
  properties: {
    r'binnedAt': PropertySchema(
      id: 0,
      name: r'binnedAt',
      type: IsarType.dateTime,
    ),
    r'binnedFromFolderId': PropertySchema(
      id: 1,
      name: r'binnedFromFolderId',
      type: IsarType.string,
    ),
    r'boxes': PropertySchema(
      id: 2,
      name: r'boxes',
      type: IsarType.objectList,
      target: r'WordBox',
    ),
    r'description': PropertySchema(
      id: 3,
      name: r'description',
      type: IsarType.string,
    ),
    r'descriptionKind': PropertySchema(
      id: 4,
      name: r'descriptionKind',
      type: IsarType.byte,
      enumMap: _WordCollectiondescriptionKindEnumValueMap,
    ),
    r'dialogues': PropertySchema(
      id: 5,
      name: r'dialogues',
      type: IsarType.objectList,
      target: r'FilmDialogue',
    ),
    r'editToken': PropertySchema(
      id: 6,
      name: r'editToken',
      type: IsarType.string,
    ),
    r'folderId': PropertySchema(
      id: 7,
      name: r'folderId',
      type: IsarType.string,
    ),
    r'groupedWordsKey': PropertySchema(
      id: 8,
      name: r'groupedWordsKey',
      type: IsarType.string,
    ),
    r'groups': PropertySchema(
      id: 9,
      name: r'groups',
      type: IsarType.objectList,
      target: r'WordGroup',
    ),
    r'isShared': PropertySchema(
      id: 10,
      name: r'isShared',
      type: IsarType.bool,
    ),
    r'keep': PropertySchema(
      id: 11,
      name: r'keep',
      type: IsarType.bool,
    ),
    r'lastLocalModifiedAt': PropertySchema(
      id: 12,
      name: r'lastLocalModifiedAt',
      type: IsarType.dateTime,
    ),
    r'name': PropertySchema(
      id: 13,
      name: r'name',
      type: IsarType.string,
    ),
    r'nameKind': PropertySchema(
      id: 14,
      name: r'nameKind',
      type: IsarType.byte,
      enumMap: _WordCollectionnameKindEnumValueMap,
    ),
    r'order': PropertySchema(
      id: 15,
      name: r'order',
      type: IsarType.long,
    ),
    r'originTags': PropertySchema(
      id: 16,
      name: r'originTags',
      type: IsarType.stringList,
    ),
    r'publishedId': PropertySchema(
      id: 17,
      name: r'publishedId',
      type: IsarType.string,
    ),
    r'results': PropertySchema(
      id: 18,
      name: r'results',
      type: IsarType.objectList,
      target: r'WordResult',
    ),
    r'selectedGroupId': PropertySchema(
      id: 19,
      name: r'selectedGroupId',
      type: IsarType.string,
    ),
    r'sessionId': PropertySchema(
      id: 20,
      name: r'sessionId',
      type: IsarType.string,
    ),
    r'sources': PropertySchema(
      id: 21,
      name: r'sources',
      type: IsarType.objectList,
      target: r'SourcePhoto',
    ),
    r'tags': PropertySchema(
      id: 22,
      name: r'tags',
      type: IsarType.stringList,
    ),
    r'topicTags': PropertySchema(
      id: 23,
      name: r'topicTags',
      type: IsarType.stringList,
    ),
    r'updatedAt': PropertySchema(
      id: 24,
      name: r'updatedAt',
      type: IsarType.dateTime,
    ),
    r'words': PropertySchema(
      id: 25,
      name: r'words',
      type: IsarType.objectList,
      target: r'WordPair',
    )
  },
  estimateSize: _wordCollectionEstimateSize,
  serialize: _wordCollectionSerialize,
  deserialize: _wordCollectionDeserialize,
  deserializeProp: _wordCollectionDeserializeProp,
  idName: r'id',
  indexes: {
    r'sessionId': IndexSchema(
      id: 6949518585047923839,
      name: r'sessionId',
      unique: true,
      replace: true,
      properties: [
        IndexPropertySchema(
          name: r'sessionId',
          type: IndexType.hash,
          caseSensitive: true,
        )
      ],
    ),
    r'folderId': IndexSchema(
      id: 6340065978996931043,
      name: r'folderId',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'folderId',
          type: IndexType.hash,
          caseSensitive: true,
        )
      ],
    ),
    r'binnedAt': IndexSchema(
      id: 3986165981865880220,
      name: r'binnedAt',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'binnedAt',
          type: IndexType.value,
          caseSensitive: false,
        )
      ],
    )
  },
  links: {},
  embeddedSchemas: {
    r'WordPair': WordPairSchema,
    r'WordOrigin': WordOriginSchema,
    r'SourcePhoto': SessionSourceSchema,
    r'WordGroup': WordGroupSchema,
    r'FilmDialogue': FilmDialogueSchema,
    r'WordResult': WordResultSchema,
    r'WordBox': WordBoxSchema
  },
  getId: _wordCollectionGetId,
  getLinks: _wordCollectionGetLinks,
  attach: _wordCollectionAttach,
  version: '3.4.1',
);

int _wordCollectionEstimateSize(
  WordCollection object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  {
    final value = object.binnedFromFolderId;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  bytesCount += 3 + object.boxes.length * 3;
  {
    final offsets = allOffsets[WordBox]!;
    for (var i = 0; i < object.boxes.length; i++) {
      final value = object.boxes[i];
      bytesCount += WordBoxSchema.estimateSize(value, offsets, allOffsets);
    }
  }
  {
    final value = object.description;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  bytesCount += 3 + object.dialogues.length * 3;
  {
    final offsets = allOffsets[FilmDialogue]!;
    for (var i = 0; i < object.dialogues.length; i++) {
      final value = object.dialogues[i];
      bytesCount += FilmDialogueSchema.estimateSize(value, offsets, allOffsets);
    }
  }
  {
    final value = object.editToken;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.folderId;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.groupedWordsKey;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  bytesCount += 3 + object.groups.length * 3;
  {
    final offsets = allOffsets[WordGroup]!;
    for (var i = 0; i < object.groups.length; i++) {
      final value = object.groups[i];
      bytesCount += WordGroupSchema.estimateSize(value, offsets, allOffsets);
    }
  }
  {
    final value = object.name;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  bytesCount += 3 + object.originTags.length * 3;
  {
    for (var i = 0; i < object.originTags.length; i++) {
      final value = object.originTags[i];
      bytesCount += value.length * 3;
    }
  }
  {
    final value = object.publishedId;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  bytesCount += 3 + object.results.length * 3;
  {
    final offsets = allOffsets[WordResult]!;
    for (var i = 0; i < object.results.length; i++) {
      final value = object.results[i];
      bytesCount += WordResultSchema.estimateSize(value, offsets, allOffsets);
    }
  }
  {
    final value = object.selectedGroupId;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  bytesCount += 3 + object.collectionId.length * 3;
  bytesCount += 3 + object.sources.length * 3;
  {
    final offsets = allOffsets[SessionSource]!;
    for (var i = 0; i < object.sources.length; i++) {
      final value = object.sources[i];
      bytesCount +=
          SessionSourceSchema.estimateSize(value, offsets, allOffsets);
    }
  }
  bytesCount += 3 + object.tags.length * 3;
  {
    for (var i = 0; i < object.tags.length; i++) {
      final value = object.tags[i];
      bytesCount += value.length * 3;
    }
  }
  bytesCount += 3 + object.topicTags.length * 3;
  {
    for (var i = 0; i < object.topicTags.length; i++) {
      final value = object.topicTags[i];
      bytesCount += value.length * 3;
    }
  }
  bytesCount += 3 + object.words.length * 3;
  {
    final offsets = allOffsets[WordPair]!;
    for (var i = 0; i < object.words.length; i++) {
      final value = object.words[i];
      bytesCount += WordPairSchema.estimateSize(value, offsets, allOffsets);
    }
  }
  return bytesCount;
}

void _wordCollectionSerialize(
  WordCollection object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeDateTime(offsets[0], object.binnedAt);
  writer.writeString(offsets[1], object.binnedFromFolderId);
  writer.writeObjectList<WordBox>(
    offsets[2],
    allOffsets,
    WordBoxSchema.serialize,
    object.boxes,
  );
  writer.writeString(offsets[3], object.description);
  writer.writeByte(offsets[4], object.descriptionKind.index);
  writer.writeObjectList<FilmDialogue>(
    offsets[5],
    allOffsets,
    FilmDialogueSchema.serialize,
    object.dialogues,
  );
  writer.writeString(offsets[6], object.editToken);
  writer.writeString(offsets[7], object.folderId);
  writer.writeString(offsets[8], object.groupedWordsKey);
  writer.writeObjectList<WordGroup>(
    offsets[9],
    allOffsets,
    WordGroupSchema.serialize,
    object.groups,
  );
  writer.writeBool(offsets[10], object.isShared);
  writer.writeBool(offsets[11], object.keep);
  writer.writeDateTime(offsets[12], object.lastLocalModifiedAt);
  writer.writeString(offsets[13], object.name);
  writer.writeByte(offsets[14], object.nameKind.index);
  writer.writeLong(offsets[15], object.order);
  writer.writeStringList(offsets[16], object.originTags);
  writer.writeString(offsets[17], object.publishedId);
  writer.writeObjectList<WordResult>(
    offsets[18],
    allOffsets,
    WordResultSchema.serialize,
    object.results,
  );
  writer.writeString(offsets[19], object.selectedGroupId);
  writer.writeString(offsets[20], object.collectionId);
  writer.writeObjectList<SessionSource>(
    offsets[21],
    allOffsets,
    SessionSourceSchema.serialize,
    object.sources,
  );
  writer.writeStringList(offsets[22], object.tags);
  writer.writeStringList(offsets[23], object.topicTags);
  writer.writeDateTime(offsets[24], object.updatedAt);
  writer.writeObjectList<WordPair>(
    offsets[25],
    allOffsets,
    WordPairSchema.serialize,
    object.words,
  );
}

WordCollection _wordCollectionDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = WordCollection();
  object.binnedAt = reader.readDateTimeOrNull(offsets[0]);
  object.binnedFromFolderId = reader.readStringOrNull(offsets[1]);
  object.boxes = reader.readObjectList<WordBox>(
        offsets[2],
        WordBoxSchema.deserialize,
        allOffsets,
        WordBox(),
      ) ??
      [];
  object.description = reader.readStringOrNull(offsets[3]);
  object.descriptionKind = _WordCollectiondescriptionKindValueEnumMap[
          reader.readByteOrNull(offsets[4])] ??
      NameKind.undefined;
  object.dialogues = reader.readObjectList<FilmDialogue>(
        offsets[5],
        FilmDialogueSchema.deserialize,
        allOffsets,
        FilmDialogue(),
      ) ??
      [];
  object.editToken = reader.readStringOrNull(offsets[6]);
  object.folderId = reader.readStringOrNull(offsets[7]);
  object.groupedWordsKey = reader.readStringOrNull(offsets[8]);
  object.groups = reader.readObjectList<WordGroup>(
        offsets[9],
        WordGroupSchema.deserialize,
        allOffsets,
        WordGroup(),
      ) ??
      [];
  object.id = id;
  object.isShared = reader.readBool(offsets[10]);
  object.keep = reader.readBool(offsets[11]);
  object.lastLocalModifiedAt = reader.readDateTime(offsets[12]);
  object.name = reader.readStringOrNull(offsets[13]);
  object.nameKind =
      _WordCollectionnameKindValueEnumMap[reader.readByteOrNull(offsets[14])] ??
          NameKind.undefined;
  object.order = reader.readLong(offsets[15]);
  object.originTags = reader.readStringList(offsets[16]) ?? [];
  object.publishedId = reader.readStringOrNull(offsets[17]);
  object.results = reader.readObjectList<WordResult>(
        offsets[18],
        WordResultSchema.deserialize,
        allOffsets,
        WordResult(),
      ) ??
      [];
  object.selectedGroupId = reader.readStringOrNull(offsets[19]);
  object.collectionId = reader.readString(offsets[20]);
  object.sources = reader.readObjectList<SessionSource>(
        offsets[21],
        SessionSourceSchema.deserialize,
        allOffsets,
        SessionSource(),
      ) ??
      [];
  object.tags = reader.readStringList(offsets[22]) ?? [];
  object.topicTags = reader.readStringList(offsets[23]) ?? [];
  object.updatedAt = reader.readDateTime(offsets[24]);
  object.words = reader.readObjectList<WordPair>(
        offsets[25],
        WordPairSchema.deserialize,
        allOffsets,
        WordPair(),
      ) ??
      [];
  return object;
}

P _wordCollectionDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readDateTimeOrNull(offset)) as P;
    case 1:
      return (reader.readStringOrNull(offset)) as P;
    case 2:
      return (reader.readObjectList<WordBox>(
            offset,
            WordBoxSchema.deserialize,
            allOffsets,
            WordBox(),
          ) ??
          []) as P;
    case 3:
      return (reader.readStringOrNull(offset)) as P;
    case 4:
      return (_WordCollectiondescriptionKindValueEnumMap[
              reader.readByteOrNull(offset)] ??
          NameKind.undefined) as P;
    case 5:
      return (reader.readObjectList<FilmDialogue>(
            offset,
            FilmDialogueSchema.deserialize,
            allOffsets,
            FilmDialogue(),
          ) ??
          []) as P;
    case 6:
      return (reader.readStringOrNull(offset)) as P;
    case 7:
      return (reader.readStringOrNull(offset)) as P;
    case 8:
      return (reader.readStringOrNull(offset)) as P;
    case 9:
      return (reader.readObjectList<WordGroup>(
            offset,
            WordGroupSchema.deserialize,
            allOffsets,
            WordGroup(),
          ) ??
          []) as P;
    case 10:
      return (reader.readBool(offset)) as P;
    case 11:
      return (reader.readBool(offset)) as P;
    case 12:
      return (reader.readDateTime(offset)) as P;
    case 13:
      return (reader.readStringOrNull(offset)) as P;
    case 14:
      return (_WordCollectionnameKindValueEnumMap[
              reader.readByteOrNull(offset)] ??
          NameKind.undefined) as P;
    case 15:
      return (reader.readLong(offset)) as P;
    case 16:
      return (reader.readStringList(offset) ?? []) as P;
    case 17:
      return (reader.readStringOrNull(offset)) as P;
    case 18:
      return (reader.readObjectList<WordResult>(
            offset,
            WordResultSchema.deserialize,
            allOffsets,
            WordResult(),
          ) ??
          []) as P;
    case 19:
      return (reader.readStringOrNull(offset)) as P;
    case 20:
      return (reader.readString(offset)) as P;
    case 21:
      return (reader.readObjectList<SessionSource>(
            offset,
            SessionSourceSchema.deserialize,
            allOffsets,
            SessionSource(),
          ) ??
          []) as P;
    case 22:
      return (reader.readStringList(offset) ?? []) as P;
    case 23:
      return (reader.readStringList(offset) ?? []) as P;
    case 24:
      return (reader.readDateTime(offset)) as P;
    case 25:
      return (reader.readObjectList<WordPair>(
            offset,
            WordPairSchema.deserialize,
            allOffsets,
            WordPair(),
          ) ??
          []) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

const _WordCollectiondescriptionKindEnumValueMap = {
  'undefined': 0,
  'auto': 1,
  'byUser': 2,
};
const _WordCollectiondescriptionKindValueEnumMap = {
  0: NameKind.undefined,
  1: NameKind.auto,
  2: NameKind.byUser,
};
const _WordCollectionnameKindEnumValueMap = {
  'undefined': 0,
  'auto': 1,
  'byUser': 2,
};
const _WordCollectionnameKindValueEnumMap = {
  0: NameKind.undefined,
  1: NameKind.auto,
  2: NameKind.byUser,
};

Id _wordCollectionGetId(WordCollection object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _wordCollectionGetLinks(WordCollection object) {
  return [];
}

void _wordCollectionAttach(
    IsarCollection<dynamic> col, Id id, WordCollection object) {
  object.id = id;
}

extension WordCollectionByIndex on IsarCollection<WordCollection> {
  Future<WordCollection?> getByCollectionId(String collectionId) {
    return getByIndex(r'sessionId', [collectionId]);
  }

  WordCollection? getByCollectionIdSync(String collectionId) {
    return getByIndexSync(r'sessionId', [collectionId]);
  }

  Future<bool> deleteByCollectionId(String collectionId) {
    return deleteByIndex(r'sessionId', [collectionId]);
  }

  bool deleteByCollectionIdSync(String collectionId) {
    return deleteByIndexSync(r'sessionId', [collectionId]);
  }

  Future<List<WordCollection?>> getAllByCollectionId(
      List<String> collectionIdValues) {
    final values = collectionIdValues.map((e) => [e]).toList();
    return getAllByIndex(r'sessionId', values);
  }

  List<WordCollection?> getAllByCollectionIdSync(
      List<String> collectionIdValues) {
    final values = collectionIdValues.map((e) => [e]).toList();
    return getAllByIndexSync(r'sessionId', values);
  }

  Future<int> deleteAllByCollectionId(List<String> collectionIdValues) {
    final values = collectionIdValues.map((e) => [e]).toList();
    return deleteAllByIndex(r'sessionId', values);
  }

  int deleteAllByCollectionIdSync(List<String> collectionIdValues) {
    final values = collectionIdValues.map((e) => [e]).toList();
    return deleteAllByIndexSync(r'sessionId', values);
  }

  Future<Id> putByCollectionId(WordCollection object) {
    return putByIndex(r'sessionId', object);
  }

  Id putByCollectionIdSync(WordCollection object, {bool saveLinks = true}) {
    return putByIndexSync(r'sessionId', object, saveLinks: saveLinks);
  }

  Future<List<Id>> putAllByCollectionId(List<WordCollection> objects) {
    return putAllByIndex(r'sessionId', objects);
  }

  List<Id> putAllByCollectionIdSync(List<WordCollection> objects,
      {bool saveLinks = true}) {
    return putAllByIndexSync(r'sessionId', objects, saveLinks: saveLinks);
  }
}

extension WordCollectionQueryWhereSort
    on QueryBuilder<WordCollection, WordCollection, QWhere> {
  QueryBuilder<WordCollection, WordCollection, QAfterWhere> anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }

  QueryBuilder<WordCollection, WordCollection, QAfterWhere> anyBinnedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        const IndexWhereClause.any(indexName: r'binnedAt'),
      );
    });
  }
}

extension WordCollectionQueryWhere
    on QueryBuilder<WordCollection, WordCollection, QWhereClause> {
  QueryBuilder<WordCollection, WordCollection, QAfterWhereClause> idEqualTo(
      Id id) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(
        lower: id,
        upper: id,
      ));
    });
  }

  QueryBuilder<WordCollection, WordCollection, QAfterWhereClause> idNotEqualTo(
      Id id) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IdWhereClause.lessThan(upper: id, includeUpper: false),
            )
            .addWhereClause(
              IdWhereClause.greaterThan(lower: id, includeLower: false),
            );
      } else {
        return query
            .addWhereClause(
              IdWhereClause.greaterThan(lower: id, includeLower: false),
            )
            .addWhereClause(
              IdWhereClause.lessThan(upper: id, includeUpper: false),
            );
      }
    });
  }

  QueryBuilder<WordCollection, WordCollection, QAfterWhereClause> idGreaterThan(
      Id id,
      {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<WordCollection, WordCollection, QAfterWhereClause> idLessThan(
      Id id,
      {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<WordCollection, WordCollection, QAfterWhereClause> idBetween(
    Id lowerId,
    Id upperId, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(
        lower: lowerId,
        includeLower: includeLower,
        upper: upperId,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<WordCollection, WordCollection, QAfterWhereClause>
      collectionIdEqualTo(String collectionId) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'sessionId',
        value: [collectionId],
      ));
    });
  }

  QueryBuilder<WordCollection, WordCollection, QAfterWhereClause>
      collectionIdNotEqualTo(String collectionId) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'sessionId',
              lower: [],
              upper: [collectionId],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'sessionId',
              lower: [collectionId],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'sessionId',
              lower: [collectionId],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'sessionId',
              lower: [],
              upper: [collectionId],
              includeUpper: false,
            ));
      }
    });
  }

  QueryBuilder<WordCollection, WordCollection, QAfterWhereClause>
      folderIdIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'folderId',
        value: [null],
      ));
    });
  }

  QueryBuilder<WordCollection, WordCollection, QAfterWhereClause>
      folderIdIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'folderId',
        lower: [null],
        includeLower: false,
        upper: [],
      ));
    });
  }

  QueryBuilder<WordCollection, WordCollection, QAfterWhereClause>
      folderIdEqualTo(String? folderId) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'folderId',
        value: [folderId],
      ));
    });
  }

  QueryBuilder<WordCollection, WordCollection, QAfterWhereClause>
      folderIdNotEqualTo(String? folderId) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'folderId',
              lower: [],
              upper: [folderId],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'folderId',
              lower: [folderId],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'folderId',
              lower: [folderId],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'folderId',
              lower: [],
              upper: [folderId],
              includeUpper: false,
            ));
      }
    });
  }

  QueryBuilder<WordCollection, WordCollection, QAfterWhereClause>
      binnedAtIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'binnedAt',
        value: [null],
      ));
    });
  }

  QueryBuilder<WordCollection, WordCollection, QAfterWhereClause>
      binnedAtIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'binnedAt',
        lower: [null],
        includeLower: false,
        upper: [],
      ));
    });
  }

  QueryBuilder<WordCollection, WordCollection, QAfterWhereClause>
      binnedAtEqualTo(DateTime? binnedAt) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'binnedAt',
        value: [binnedAt],
      ));
    });
  }

  QueryBuilder<WordCollection, WordCollection, QAfterWhereClause>
      binnedAtNotEqualTo(DateTime? binnedAt) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'binnedAt',
              lower: [],
              upper: [binnedAt],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'binnedAt',
              lower: [binnedAt],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'binnedAt',
              lower: [binnedAt],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'binnedAt',
              lower: [],
              upper: [binnedAt],
              includeUpper: false,
            ));
      }
    });
  }

  QueryBuilder<WordCollection, WordCollection, QAfterWhereClause>
      binnedAtGreaterThan(
    DateTime? binnedAt, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'binnedAt',
        lower: [binnedAt],
        includeLower: include,
        upper: [],
      ));
    });
  }

  QueryBuilder<WordCollection, WordCollection, QAfterWhereClause>
      binnedAtLessThan(
    DateTime? binnedAt, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'binnedAt',
        lower: [],
        upper: [binnedAt],
        includeUpper: include,
      ));
    });
  }

  QueryBuilder<WordCollection, WordCollection, QAfterWhereClause>
      binnedAtBetween(
    DateTime? lowerBinnedAt,
    DateTime? upperBinnedAt, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'binnedAt',
        lower: [lowerBinnedAt],
        includeLower: includeLower,
        upper: [upperBinnedAt],
        includeUpper: includeUpper,
      ));
    });
  }
}

extension WordCollectionQueryFilter
    on QueryBuilder<WordCollection, WordCollection, QFilterCondition> {
  QueryBuilder<WordCollection, WordCollection, QAfterFilterCondition>
      binnedAtIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'binnedAt',
      ));
    });
  }

  QueryBuilder<WordCollection, WordCollection, QAfterFilterCondition>
      binnedAtIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'binnedAt',
      ));
    });
  }

  QueryBuilder<WordCollection, WordCollection, QAfterFilterCondition>
      binnedAtEqualTo(DateTime? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'binnedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<WordCollection, WordCollection, QAfterFilterCondition>
      binnedAtGreaterThan(
    DateTime? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'binnedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<WordCollection, WordCollection, QAfterFilterCondition>
      binnedAtLessThan(
    DateTime? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'binnedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<WordCollection, WordCollection, QAfterFilterCondition>
      binnedAtBetween(
    DateTime? lower,
    DateTime? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'binnedAt',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<WordCollection, WordCollection, QAfterFilterCondition>
      binnedFromFolderIdIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'binnedFromFolderId',
      ));
    });
  }

  QueryBuilder<WordCollection, WordCollection, QAfterFilterCondition>
      binnedFromFolderIdIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'binnedFromFolderId',
      ));
    });
  }

  QueryBuilder<WordCollection, WordCollection, QAfterFilterCondition>
      binnedFromFolderIdEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'binnedFromFolderId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<WordCollection, WordCollection, QAfterFilterCondition>
      binnedFromFolderIdGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'binnedFromFolderId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<WordCollection, WordCollection, QAfterFilterCondition>
      binnedFromFolderIdLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'binnedFromFolderId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<WordCollection, WordCollection, QAfterFilterCondition>
      binnedFromFolderIdBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'binnedFromFolderId',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<WordCollection, WordCollection, QAfterFilterCondition>
      binnedFromFolderIdStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'binnedFromFolderId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<WordCollection, WordCollection, QAfterFilterCondition>
      binnedFromFolderIdEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'binnedFromFolderId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<WordCollection, WordCollection, QAfterFilterCondition>
      binnedFromFolderIdContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'binnedFromFolderId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<WordCollection, WordCollection, QAfterFilterCondition>
      binnedFromFolderIdMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'binnedFromFolderId',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<WordCollection, WordCollection, QAfterFilterCondition>
      binnedFromFolderIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'binnedFromFolderId',
        value: '',
      ));
    });
  }

  QueryBuilder<WordCollection, WordCollection, QAfterFilterCondition>
      binnedFromFolderIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'binnedFromFolderId',
        value: '',
      ));
    });
  }

  QueryBuilder<WordCollection, WordCollection, QAfterFilterCondition>
      boxesLengthEqualTo(int length) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'boxes',
        length,
        true,
        length,
        true,
      );
    });
  }

  QueryBuilder<WordCollection, WordCollection, QAfterFilterCondition>
      boxesIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'boxes',
        0,
        true,
        0,
        true,
      );
    });
  }

  QueryBuilder<WordCollection, WordCollection, QAfterFilterCondition>
      boxesIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'boxes',
        0,
        false,
        999999,
        true,
      );
    });
  }

  QueryBuilder<WordCollection, WordCollection, QAfterFilterCondition>
      boxesLengthLessThan(
    int length, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'boxes',
        0,
        true,
        length,
        include,
      );
    });
  }

  QueryBuilder<WordCollection, WordCollection, QAfterFilterCondition>
      boxesLengthGreaterThan(
    int length, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'boxes',
        length,
        include,
        999999,
        true,
      );
    });
  }

  QueryBuilder<WordCollection, WordCollection, QAfterFilterCondition>
      boxesLengthBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'boxes',
        lower,
        includeLower,
        upper,
        includeUpper,
      );
    });
  }

  QueryBuilder<WordCollection, WordCollection, QAfterFilterCondition>
      descriptionIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'description',
      ));
    });
  }

  QueryBuilder<WordCollection, WordCollection, QAfterFilterCondition>
      descriptionIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'description',
      ));
    });
  }

  QueryBuilder<WordCollection, WordCollection, QAfterFilterCondition>
      descriptionEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'description',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<WordCollection, WordCollection, QAfterFilterCondition>
      descriptionGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'description',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<WordCollection, WordCollection, QAfterFilterCondition>
      descriptionLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'description',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<WordCollection, WordCollection, QAfterFilterCondition>
      descriptionBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'description',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<WordCollection, WordCollection, QAfterFilterCondition>
      descriptionStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'description',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<WordCollection, WordCollection, QAfterFilterCondition>
      descriptionEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'description',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<WordCollection, WordCollection, QAfterFilterCondition>
      descriptionContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'description',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<WordCollection, WordCollection, QAfterFilterCondition>
      descriptionMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'description',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<WordCollection, WordCollection, QAfterFilterCondition>
      descriptionIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'description',
        value: '',
      ));
    });
  }

  QueryBuilder<WordCollection, WordCollection, QAfterFilterCondition>
      descriptionIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'description',
        value: '',
      ));
    });
  }

  QueryBuilder<WordCollection, WordCollection, QAfterFilterCondition>
      descriptionKindEqualTo(NameKind value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'descriptionKind',
        value: value,
      ));
    });
  }

  QueryBuilder<WordCollection, WordCollection, QAfterFilterCondition>
      descriptionKindGreaterThan(
    NameKind value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'descriptionKind',
        value: value,
      ));
    });
  }

  QueryBuilder<WordCollection, WordCollection, QAfterFilterCondition>
      descriptionKindLessThan(
    NameKind value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'descriptionKind',
        value: value,
      ));
    });
  }

  QueryBuilder<WordCollection, WordCollection, QAfterFilterCondition>
      descriptionKindBetween(
    NameKind lower,
    NameKind upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'descriptionKind',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<WordCollection, WordCollection, QAfterFilterCondition>
      dialoguesLengthEqualTo(int length) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'dialogues',
        length,
        true,
        length,
        true,
      );
    });
  }

  QueryBuilder<WordCollection, WordCollection, QAfterFilterCondition>
      dialoguesIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'dialogues',
        0,
        true,
        0,
        true,
      );
    });
  }

  QueryBuilder<WordCollection, WordCollection, QAfterFilterCondition>
      dialoguesIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'dialogues',
        0,
        false,
        999999,
        true,
      );
    });
  }

  QueryBuilder<WordCollection, WordCollection, QAfterFilterCondition>
      dialoguesLengthLessThan(
    int length, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'dialogues',
        0,
        true,
        length,
        include,
      );
    });
  }

  QueryBuilder<WordCollection, WordCollection, QAfterFilterCondition>
      dialoguesLengthGreaterThan(
    int length, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'dialogues',
        length,
        include,
        999999,
        true,
      );
    });
  }

  QueryBuilder<WordCollection, WordCollection, QAfterFilterCondition>
      dialoguesLengthBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'dialogues',
        lower,
        includeLower,
        upper,
        includeUpper,
      );
    });
  }

  QueryBuilder<WordCollection, WordCollection, QAfterFilterCondition>
      editTokenIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'editToken',
      ));
    });
  }

  QueryBuilder<WordCollection, WordCollection, QAfterFilterCondition>
      editTokenIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'editToken',
      ));
    });
  }

  QueryBuilder<WordCollection, WordCollection, QAfterFilterCondition>
      editTokenEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'editToken',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<WordCollection, WordCollection, QAfterFilterCondition>
      editTokenGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'editToken',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<WordCollection, WordCollection, QAfterFilterCondition>
      editTokenLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'editToken',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<WordCollection, WordCollection, QAfterFilterCondition>
      editTokenBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'editToken',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<WordCollection, WordCollection, QAfterFilterCondition>
      editTokenStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'editToken',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<WordCollection, WordCollection, QAfterFilterCondition>
      editTokenEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'editToken',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<WordCollection, WordCollection, QAfterFilterCondition>
      editTokenContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'editToken',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<WordCollection, WordCollection, QAfterFilterCondition>
      editTokenMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'editToken',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<WordCollection, WordCollection, QAfterFilterCondition>
      editTokenIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'editToken',
        value: '',
      ));
    });
  }

  QueryBuilder<WordCollection, WordCollection, QAfterFilterCondition>
      editTokenIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'editToken',
        value: '',
      ));
    });
  }

  QueryBuilder<WordCollection, WordCollection, QAfterFilterCondition>
      folderIdIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'folderId',
      ));
    });
  }

  QueryBuilder<WordCollection, WordCollection, QAfterFilterCondition>
      folderIdIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'folderId',
      ));
    });
  }

  QueryBuilder<WordCollection, WordCollection, QAfterFilterCondition>
      folderIdEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'folderId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<WordCollection, WordCollection, QAfterFilterCondition>
      folderIdGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'folderId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<WordCollection, WordCollection, QAfterFilterCondition>
      folderIdLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'folderId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<WordCollection, WordCollection, QAfterFilterCondition>
      folderIdBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'folderId',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<WordCollection, WordCollection, QAfterFilterCondition>
      folderIdStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'folderId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<WordCollection, WordCollection, QAfterFilterCondition>
      folderIdEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'folderId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<WordCollection, WordCollection, QAfterFilterCondition>
      folderIdContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'folderId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<WordCollection, WordCollection, QAfterFilterCondition>
      folderIdMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'folderId',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<WordCollection, WordCollection, QAfterFilterCondition>
      folderIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'folderId',
        value: '',
      ));
    });
  }

  QueryBuilder<WordCollection, WordCollection, QAfterFilterCondition>
      folderIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'folderId',
        value: '',
      ));
    });
  }

  QueryBuilder<WordCollection, WordCollection, QAfterFilterCondition>
      groupedWordsKeyIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'groupedWordsKey',
      ));
    });
  }

  QueryBuilder<WordCollection, WordCollection, QAfterFilterCondition>
      groupedWordsKeyIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'groupedWordsKey',
      ));
    });
  }

  QueryBuilder<WordCollection, WordCollection, QAfterFilterCondition>
      groupedWordsKeyEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'groupedWordsKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<WordCollection, WordCollection, QAfterFilterCondition>
      groupedWordsKeyGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'groupedWordsKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<WordCollection, WordCollection, QAfterFilterCondition>
      groupedWordsKeyLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'groupedWordsKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<WordCollection, WordCollection, QAfterFilterCondition>
      groupedWordsKeyBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'groupedWordsKey',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<WordCollection, WordCollection, QAfterFilterCondition>
      groupedWordsKeyStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'groupedWordsKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<WordCollection, WordCollection, QAfterFilterCondition>
      groupedWordsKeyEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'groupedWordsKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<WordCollection, WordCollection, QAfterFilterCondition>
      groupedWordsKeyContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'groupedWordsKey',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<WordCollection, WordCollection, QAfterFilterCondition>
      groupedWordsKeyMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'groupedWordsKey',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<WordCollection, WordCollection, QAfterFilterCondition>
      groupedWordsKeyIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'groupedWordsKey',
        value: '',
      ));
    });
  }

  QueryBuilder<WordCollection, WordCollection, QAfterFilterCondition>
      groupedWordsKeyIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'groupedWordsKey',
        value: '',
      ));
    });
  }

  QueryBuilder<WordCollection, WordCollection, QAfterFilterCondition>
      groupsLengthEqualTo(int length) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'groups',
        length,
        true,
        length,
        true,
      );
    });
  }

  QueryBuilder<WordCollection, WordCollection, QAfterFilterCondition>
      groupsIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'groups',
        0,
        true,
        0,
        true,
      );
    });
  }

  QueryBuilder<WordCollection, WordCollection, QAfterFilterCondition>
      groupsIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'groups',
        0,
        false,
        999999,
        true,
      );
    });
  }

  QueryBuilder<WordCollection, WordCollection, QAfterFilterCondition>
      groupsLengthLessThan(
    int length, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'groups',
        0,
        true,
        length,
        include,
      );
    });
  }

  QueryBuilder<WordCollection, WordCollection, QAfterFilterCondition>
      groupsLengthGreaterThan(
    int length, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'groups',
        length,
        include,
        999999,
        true,
      );
    });
  }

  QueryBuilder<WordCollection, WordCollection, QAfterFilterCondition>
      groupsLengthBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'groups',
        lower,
        includeLower,
        upper,
        includeUpper,
      );
    });
  }

  QueryBuilder<WordCollection, WordCollection, QAfterFilterCondition> idEqualTo(
      Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<WordCollection, WordCollection, QAfterFilterCondition>
      idGreaterThan(
    Id value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<WordCollection, WordCollection, QAfterFilterCondition>
      idLessThan(
    Id value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<WordCollection, WordCollection, QAfterFilterCondition> idBetween(
    Id lower,
    Id upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'id',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<WordCollection, WordCollection, QAfterFilterCondition>
      isSharedEqualTo(bool value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'isShared',
        value: value,
      ));
    });
  }

  QueryBuilder<WordCollection, WordCollection, QAfterFilterCondition>
      keepEqualTo(bool value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'keep',
        value: value,
      ));
    });
  }

  QueryBuilder<WordCollection, WordCollection, QAfterFilterCondition>
      lastLocalModifiedAtEqualTo(DateTime value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'lastLocalModifiedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<WordCollection, WordCollection, QAfterFilterCondition>
      lastLocalModifiedAtGreaterThan(
    DateTime value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'lastLocalModifiedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<WordCollection, WordCollection, QAfterFilterCondition>
      lastLocalModifiedAtLessThan(
    DateTime value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'lastLocalModifiedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<WordCollection, WordCollection, QAfterFilterCondition>
      lastLocalModifiedAtBetween(
    DateTime lower,
    DateTime upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'lastLocalModifiedAt',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<WordCollection, WordCollection, QAfterFilterCondition>
      nameIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'name',
      ));
    });
  }

  QueryBuilder<WordCollection, WordCollection, QAfterFilterCondition>
      nameIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'name',
      ));
    });
  }

  QueryBuilder<WordCollection, WordCollection, QAfterFilterCondition>
      nameEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'name',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<WordCollection, WordCollection, QAfterFilterCondition>
      nameGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'name',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<WordCollection, WordCollection, QAfterFilterCondition>
      nameLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'name',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<WordCollection, WordCollection, QAfterFilterCondition>
      nameBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'name',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<WordCollection, WordCollection, QAfterFilterCondition>
      nameStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'name',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<WordCollection, WordCollection, QAfterFilterCondition>
      nameEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'name',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<WordCollection, WordCollection, QAfterFilterCondition>
      nameContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'name',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<WordCollection, WordCollection, QAfterFilterCondition>
      nameMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'name',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<WordCollection, WordCollection, QAfterFilterCondition>
      nameIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'name',
        value: '',
      ));
    });
  }

  QueryBuilder<WordCollection, WordCollection, QAfterFilterCondition>
      nameIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'name',
        value: '',
      ));
    });
  }

  QueryBuilder<WordCollection, WordCollection, QAfterFilterCondition>
      nameKindEqualTo(NameKind value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'nameKind',
        value: value,
      ));
    });
  }

  QueryBuilder<WordCollection, WordCollection, QAfterFilterCondition>
      nameKindGreaterThan(
    NameKind value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'nameKind',
        value: value,
      ));
    });
  }

  QueryBuilder<WordCollection, WordCollection, QAfterFilterCondition>
      nameKindLessThan(
    NameKind value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'nameKind',
        value: value,
      ));
    });
  }

  QueryBuilder<WordCollection, WordCollection, QAfterFilterCondition>
      nameKindBetween(
    NameKind lower,
    NameKind upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'nameKind',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<WordCollection, WordCollection, QAfterFilterCondition>
      orderEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'order',
        value: value,
      ));
    });
  }

  QueryBuilder<WordCollection, WordCollection, QAfterFilterCondition>
      orderGreaterThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'order',
        value: value,
      ));
    });
  }

  QueryBuilder<WordCollection, WordCollection, QAfterFilterCondition>
      orderLessThan(
    int value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'order',
        value: value,
      ));
    });
  }

  QueryBuilder<WordCollection, WordCollection, QAfterFilterCondition>
      orderBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'order',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<WordCollection, WordCollection, QAfterFilterCondition>
      originTagsElementEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'originTags',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<WordCollection, WordCollection, QAfterFilterCondition>
      originTagsElementGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'originTags',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<WordCollection, WordCollection, QAfterFilterCondition>
      originTagsElementLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'originTags',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<WordCollection, WordCollection, QAfterFilterCondition>
      originTagsElementBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'originTags',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<WordCollection, WordCollection, QAfterFilterCondition>
      originTagsElementStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'originTags',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<WordCollection, WordCollection, QAfterFilterCondition>
      originTagsElementEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'originTags',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<WordCollection, WordCollection, QAfterFilterCondition>
      originTagsElementContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'originTags',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<WordCollection, WordCollection, QAfterFilterCondition>
      originTagsElementMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'originTags',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<WordCollection, WordCollection, QAfterFilterCondition>
      originTagsElementIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'originTags',
        value: '',
      ));
    });
  }

  QueryBuilder<WordCollection, WordCollection, QAfterFilterCondition>
      originTagsElementIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'originTags',
        value: '',
      ));
    });
  }

  QueryBuilder<WordCollection, WordCollection, QAfterFilterCondition>
      originTagsLengthEqualTo(int length) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'originTags',
        length,
        true,
        length,
        true,
      );
    });
  }

  QueryBuilder<WordCollection, WordCollection, QAfterFilterCondition>
      originTagsIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'originTags',
        0,
        true,
        0,
        true,
      );
    });
  }

  QueryBuilder<WordCollection, WordCollection, QAfterFilterCondition>
      originTagsIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'originTags',
        0,
        false,
        999999,
        true,
      );
    });
  }

  QueryBuilder<WordCollection, WordCollection, QAfterFilterCondition>
      originTagsLengthLessThan(
    int length, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'originTags',
        0,
        true,
        length,
        include,
      );
    });
  }

  QueryBuilder<WordCollection, WordCollection, QAfterFilterCondition>
      originTagsLengthGreaterThan(
    int length, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'originTags',
        length,
        include,
        999999,
        true,
      );
    });
  }

  QueryBuilder<WordCollection, WordCollection, QAfterFilterCondition>
      originTagsLengthBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'originTags',
        lower,
        includeLower,
        upper,
        includeUpper,
      );
    });
  }

  QueryBuilder<WordCollection, WordCollection, QAfterFilterCondition>
      publishedIdIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'publishedId',
      ));
    });
  }

  QueryBuilder<WordCollection, WordCollection, QAfterFilterCondition>
      publishedIdIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'publishedId',
      ));
    });
  }

  QueryBuilder<WordCollection, WordCollection, QAfterFilterCondition>
      publishedIdEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'publishedId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<WordCollection, WordCollection, QAfterFilterCondition>
      publishedIdGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'publishedId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<WordCollection, WordCollection, QAfterFilterCondition>
      publishedIdLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'publishedId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<WordCollection, WordCollection, QAfterFilterCondition>
      publishedIdBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'publishedId',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<WordCollection, WordCollection, QAfterFilterCondition>
      publishedIdStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'publishedId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<WordCollection, WordCollection, QAfterFilterCondition>
      publishedIdEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'publishedId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<WordCollection, WordCollection, QAfterFilterCondition>
      publishedIdContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'publishedId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<WordCollection, WordCollection, QAfterFilterCondition>
      publishedIdMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'publishedId',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<WordCollection, WordCollection, QAfterFilterCondition>
      publishedIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'publishedId',
        value: '',
      ));
    });
  }

  QueryBuilder<WordCollection, WordCollection, QAfterFilterCondition>
      publishedIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'publishedId',
        value: '',
      ));
    });
  }

  QueryBuilder<WordCollection, WordCollection, QAfterFilterCondition>
      resultsLengthEqualTo(int length) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'results',
        length,
        true,
        length,
        true,
      );
    });
  }

  QueryBuilder<WordCollection, WordCollection, QAfterFilterCondition>
      resultsIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'results',
        0,
        true,
        0,
        true,
      );
    });
  }

  QueryBuilder<WordCollection, WordCollection, QAfterFilterCondition>
      resultsIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'results',
        0,
        false,
        999999,
        true,
      );
    });
  }

  QueryBuilder<WordCollection, WordCollection, QAfterFilterCondition>
      resultsLengthLessThan(
    int length, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'results',
        0,
        true,
        length,
        include,
      );
    });
  }

  QueryBuilder<WordCollection, WordCollection, QAfterFilterCondition>
      resultsLengthGreaterThan(
    int length, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'results',
        length,
        include,
        999999,
        true,
      );
    });
  }

  QueryBuilder<WordCollection, WordCollection, QAfterFilterCondition>
      resultsLengthBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'results',
        lower,
        includeLower,
        upper,
        includeUpper,
      );
    });
  }

  QueryBuilder<WordCollection, WordCollection, QAfterFilterCondition>
      selectedGroupIdIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'selectedGroupId',
      ));
    });
  }

  QueryBuilder<WordCollection, WordCollection, QAfterFilterCondition>
      selectedGroupIdIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'selectedGroupId',
      ));
    });
  }

  QueryBuilder<WordCollection, WordCollection, QAfterFilterCondition>
      selectedGroupIdEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'selectedGroupId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<WordCollection, WordCollection, QAfterFilterCondition>
      selectedGroupIdGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'selectedGroupId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<WordCollection, WordCollection, QAfterFilterCondition>
      selectedGroupIdLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'selectedGroupId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<WordCollection, WordCollection, QAfterFilterCondition>
      selectedGroupIdBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'selectedGroupId',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<WordCollection, WordCollection, QAfterFilterCondition>
      selectedGroupIdStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'selectedGroupId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<WordCollection, WordCollection, QAfterFilterCondition>
      selectedGroupIdEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'selectedGroupId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<WordCollection, WordCollection, QAfterFilterCondition>
      selectedGroupIdContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'selectedGroupId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<WordCollection, WordCollection, QAfterFilterCondition>
      selectedGroupIdMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'selectedGroupId',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<WordCollection, WordCollection, QAfterFilterCondition>
      selectedGroupIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'selectedGroupId',
        value: '',
      ));
    });
  }

  QueryBuilder<WordCollection, WordCollection, QAfterFilterCondition>
      selectedGroupIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'selectedGroupId',
        value: '',
      ));
    });
  }

  QueryBuilder<WordCollection, WordCollection, QAfterFilterCondition>
      collectionIdEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'sessionId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<WordCollection, WordCollection, QAfterFilterCondition>
      collectionIdGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'sessionId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<WordCollection, WordCollection, QAfterFilterCondition>
      collectionIdLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'sessionId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<WordCollection, WordCollection, QAfterFilterCondition>
      collectionIdBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'sessionId',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<WordCollection, WordCollection, QAfterFilterCondition>
      collectionIdStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'sessionId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<WordCollection, WordCollection, QAfterFilterCondition>
      collectionIdEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'sessionId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<WordCollection, WordCollection, QAfterFilterCondition>
      collectionIdContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'sessionId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<WordCollection, WordCollection, QAfterFilterCondition>
      collectionIdMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'sessionId',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<WordCollection, WordCollection, QAfterFilterCondition>
      collectionIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'sessionId',
        value: '',
      ));
    });
  }

  QueryBuilder<WordCollection, WordCollection, QAfterFilterCondition>
      collectionIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'sessionId',
        value: '',
      ));
    });
  }

  QueryBuilder<WordCollection, WordCollection, QAfterFilterCondition>
      sourcesLengthEqualTo(int length) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'sources',
        length,
        true,
        length,
        true,
      );
    });
  }

  QueryBuilder<WordCollection, WordCollection, QAfterFilterCondition>
      sourcesIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'sources',
        0,
        true,
        0,
        true,
      );
    });
  }

  QueryBuilder<WordCollection, WordCollection, QAfterFilterCondition>
      sourcesIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'sources',
        0,
        false,
        999999,
        true,
      );
    });
  }

  QueryBuilder<WordCollection, WordCollection, QAfterFilterCondition>
      sourcesLengthLessThan(
    int length, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'sources',
        0,
        true,
        length,
        include,
      );
    });
  }

  QueryBuilder<WordCollection, WordCollection, QAfterFilterCondition>
      sourcesLengthGreaterThan(
    int length, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'sources',
        length,
        include,
        999999,
        true,
      );
    });
  }

  QueryBuilder<WordCollection, WordCollection, QAfterFilterCondition>
      sourcesLengthBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'sources',
        lower,
        includeLower,
        upper,
        includeUpper,
      );
    });
  }

  QueryBuilder<WordCollection, WordCollection, QAfterFilterCondition>
      tagsElementEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'tags',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<WordCollection, WordCollection, QAfterFilterCondition>
      tagsElementGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'tags',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<WordCollection, WordCollection, QAfterFilterCondition>
      tagsElementLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'tags',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<WordCollection, WordCollection, QAfterFilterCondition>
      tagsElementBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'tags',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<WordCollection, WordCollection, QAfterFilterCondition>
      tagsElementStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'tags',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<WordCollection, WordCollection, QAfterFilterCondition>
      tagsElementEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'tags',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<WordCollection, WordCollection, QAfterFilterCondition>
      tagsElementContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'tags',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<WordCollection, WordCollection, QAfterFilterCondition>
      tagsElementMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'tags',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<WordCollection, WordCollection, QAfterFilterCondition>
      tagsElementIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'tags',
        value: '',
      ));
    });
  }

  QueryBuilder<WordCollection, WordCollection, QAfterFilterCondition>
      tagsElementIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'tags',
        value: '',
      ));
    });
  }

  QueryBuilder<WordCollection, WordCollection, QAfterFilterCondition>
      tagsLengthEqualTo(int length) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'tags',
        length,
        true,
        length,
        true,
      );
    });
  }

  QueryBuilder<WordCollection, WordCollection, QAfterFilterCondition>
      tagsIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'tags',
        0,
        true,
        0,
        true,
      );
    });
  }

  QueryBuilder<WordCollection, WordCollection, QAfterFilterCondition>
      tagsIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'tags',
        0,
        false,
        999999,
        true,
      );
    });
  }

  QueryBuilder<WordCollection, WordCollection, QAfterFilterCondition>
      tagsLengthLessThan(
    int length, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'tags',
        0,
        true,
        length,
        include,
      );
    });
  }

  QueryBuilder<WordCollection, WordCollection, QAfterFilterCondition>
      tagsLengthGreaterThan(
    int length, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'tags',
        length,
        include,
        999999,
        true,
      );
    });
  }

  QueryBuilder<WordCollection, WordCollection, QAfterFilterCondition>
      tagsLengthBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'tags',
        lower,
        includeLower,
        upper,
        includeUpper,
      );
    });
  }

  QueryBuilder<WordCollection, WordCollection, QAfterFilterCondition>
      topicTagsElementEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'topicTags',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<WordCollection, WordCollection, QAfterFilterCondition>
      topicTagsElementGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'topicTags',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<WordCollection, WordCollection, QAfterFilterCondition>
      topicTagsElementLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'topicTags',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<WordCollection, WordCollection, QAfterFilterCondition>
      topicTagsElementBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'topicTags',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<WordCollection, WordCollection, QAfterFilterCondition>
      topicTagsElementStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'topicTags',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<WordCollection, WordCollection, QAfterFilterCondition>
      topicTagsElementEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'topicTags',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<WordCollection, WordCollection, QAfterFilterCondition>
      topicTagsElementContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'topicTags',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<WordCollection, WordCollection, QAfterFilterCondition>
      topicTagsElementMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'topicTags',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<WordCollection, WordCollection, QAfterFilterCondition>
      topicTagsElementIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'topicTags',
        value: '',
      ));
    });
  }

  QueryBuilder<WordCollection, WordCollection, QAfterFilterCondition>
      topicTagsElementIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'topicTags',
        value: '',
      ));
    });
  }

  QueryBuilder<WordCollection, WordCollection, QAfterFilterCondition>
      topicTagsLengthEqualTo(int length) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'topicTags',
        length,
        true,
        length,
        true,
      );
    });
  }

  QueryBuilder<WordCollection, WordCollection, QAfterFilterCondition>
      topicTagsIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'topicTags',
        0,
        true,
        0,
        true,
      );
    });
  }

  QueryBuilder<WordCollection, WordCollection, QAfterFilterCondition>
      topicTagsIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'topicTags',
        0,
        false,
        999999,
        true,
      );
    });
  }

  QueryBuilder<WordCollection, WordCollection, QAfterFilterCondition>
      topicTagsLengthLessThan(
    int length, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'topicTags',
        0,
        true,
        length,
        include,
      );
    });
  }

  QueryBuilder<WordCollection, WordCollection, QAfterFilterCondition>
      topicTagsLengthGreaterThan(
    int length, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'topicTags',
        length,
        include,
        999999,
        true,
      );
    });
  }

  QueryBuilder<WordCollection, WordCollection, QAfterFilterCondition>
      topicTagsLengthBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'topicTags',
        lower,
        includeLower,
        upper,
        includeUpper,
      );
    });
  }

  QueryBuilder<WordCollection, WordCollection, QAfterFilterCondition>
      updatedAtEqualTo(DateTime value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'updatedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<WordCollection, WordCollection, QAfterFilterCondition>
      updatedAtGreaterThan(
    DateTime value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'updatedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<WordCollection, WordCollection, QAfterFilterCondition>
      updatedAtLessThan(
    DateTime value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'updatedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<WordCollection, WordCollection, QAfterFilterCondition>
      updatedAtBetween(
    DateTime lower,
    DateTime upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'updatedAt',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<WordCollection, WordCollection, QAfterFilterCondition>
      wordsLengthEqualTo(int length) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'words',
        length,
        true,
        length,
        true,
      );
    });
  }

  QueryBuilder<WordCollection, WordCollection, QAfterFilterCondition>
      wordsIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'words',
        0,
        true,
        0,
        true,
      );
    });
  }

  QueryBuilder<WordCollection, WordCollection, QAfterFilterCondition>
      wordsIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'words',
        0,
        false,
        999999,
        true,
      );
    });
  }

  QueryBuilder<WordCollection, WordCollection, QAfterFilterCondition>
      wordsLengthLessThan(
    int length, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'words',
        0,
        true,
        length,
        include,
      );
    });
  }

  QueryBuilder<WordCollection, WordCollection, QAfterFilterCondition>
      wordsLengthGreaterThan(
    int length, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'words',
        length,
        include,
        999999,
        true,
      );
    });
  }

  QueryBuilder<WordCollection, WordCollection, QAfterFilterCondition>
      wordsLengthBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'words',
        lower,
        includeLower,
        upper,
        includeUpper,
      );
    });
  }
}

extension WordCollectionQueryObject
    on QueryBuilder<WordCollection, WordCollection, QFilterCondition> {
  QueryBuilder<WordCollection, WordCollection, QAfterFilterCondition>
      boxesElement(FilterQuery<WordBox> q) {
    return QueryBuilder.apply(this, (query) {
      return query.object(q, r'boxes');
    });
  }

  QueryBuilder<WordCollection, WordCollection, QAfterFilterCondition>
      dialoguesElement(FilterQuery<FilmDialogue> q) {
    return QueryBuilder.apply(this, (query) {
      return query.object(q, r'dialogues');
    });
  }

  QueryBuilder<WordCollection, WordCollection, QAfterFilterCondition>
      groupsElement(FilterQuery<WordGroup> q) {
    return QueryBuilder.apply(this, (query) {
      return query.object(q, r'groups');
    });
  }

  QueryBuilder<WordCollection, WordCollection, QAfterFilterCondition>
      resultsElement(FilterQuery<WordResult> q) {
    return QueryBuilder.apply(this, (query) {
      return query.object(q, r'results');
    });
  }

  QueryBuilder<WordCollection, WordCollection, QAfterFilterCondition>
      sourcesElement(FilterQuery<SessionSource> q) {
    return QueryBuilder.apply(this, (query) {
      return query.object(q, r'sources');
    });
  }

  QueryBuilder<WordCollection, WordCollection, QAfterFilterCondition>
      wordsElement(FilterQuery<WordPair> q) {
    return QueryBuilder.apply(this, (query) {
      return query.object(q, r'words');
    });
  }
}

extension WordCollectionQueryLinks
    on QueryBuilder<WordCollection, WordCollection, QFilterCondition> {}

extension WordCollectionQuerySortBy
    on QueryBuilder<WordCollection, WordCollection, QSortBy> {
  QueryBuilder<WordCollection, WordCollection, QAfterSortBy> sortByBinnedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'binnedAt', Sort.asc);
    });
  }

  QueryBuilder<WordCollection, WordCollection, QAfterSortBy>
      sortByBinnedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'binnedAt', Sort.desc);
    });
  }

  QueryBuilder<WordCollection, WordCollection, QAfterSortBy>
      sortByBinnedFromFolderId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'binnedFromFolderId', Sort.asc);
    });
  }

  QueryBuilder<WordCollection, WordCollection, QAfterSortBy>
      sortByBinnedFromFolderIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'binnedFromFolderId', Sort.desc);
    });
  }

  QueryBuilder<WordCollection, WordCollection, QAfterSortBy>
      sortByDescription() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'description', Sort.asc);
    });
  }

  QueryBuilder<WordCollection, WordCollection, QAfterSortBy>
      sortByDescriptionDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'description', Sort.desc);
    });
  }

  QueryBuilder<WordCollection, WordCollection, QAfterSortBy>
      sortByDescriptionKind() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'descriptionKind', Sort.asc);
    });
  }

  QueryBuilder<WordCollection, WordCollection, QAfterSortBy>
      sortByDescriptionKindDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'descriptionKind', Sort.desc);
    });
  }

  QueryBuilder<WordCollection, WordCollection, QAfterSortBy> sortByEditToken() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'editToken', Sort.asc);
    });
  }

  QueryBuilder<WordCollection, WordCollection, QAfterSortBy>
      sortByEditTokenDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'editToken', Sort.desc);
    });
  }

  QueryBuilder<WordCollection, WordCollection, QAfterSortBy> sortByFolderId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'folderId', Sort.asc);
    });
  }

  QueryBuilder<WordCollection, WordCollection, QAfterSortBy>
      sortByFolderIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'folderId', Sort.desc);
    });
  }

  QueryBuilder<WordCollection, WordCollection, QAfterSortBy>
      sortByGroupedWordsKey() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'groupedWordsKey', Sort.asc);
    });
  }

  QueryBuilder<WordCollection, WordCollection, QAfterSortBy>
      sortByGroupedWordsKeyDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'groupedWordsKey', Sort.desc);
    });
  }

  QueryBuilder<WordCollection, WordCollection, QAfterSortBy> sortByIsShared() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isShared', Sort.asc);
    });
  }

  QueryBuilder<WordCollection, WordCollection, QAfterSortBy>
      sortByIsSharedDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isShared', Sort.desc);
    });
  }

  QueryBuilder<WordCollection, WordCollection, QAfterSortBy> sortByKeep() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'keep', Sort.asc);
    });
  }

  QueryBuilder<WordCollection, WordCollection, QAfterSortBy> sortByKeepDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'keep', Sort.desc);
    });
  }

  QueryBuilder<WordCollection, WordCollection, QAfterSortBy>
      sortByLastLocalModifiedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastLocalModifiedAt', Sort.asc);
    });
  }

  QueryBuilder<WordCollection, WordCollection, QAfterSortBy>
      sortByLastLocalModifiedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastLocalModifiedAt', Sort.desc);
    });
  }

  QueryBuilder<WordCollection, WordCollection, QAfterSortBy> sortByName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'name', Sort.asc);
    });
  }

  QueryBuilder<WordCollection, WordCollection, QAfterSortBy> sortByNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'name', Sort.desc);
    });
  }

  QueryBuilder<WordCollection, WordCollection, QAfterSortBy> sortByNameKind() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'nameKind', Sort.asc);
    });
  }

  QueryBuilder<WordCollection, WordCollection, QAfterSortBy>
      sortByNameKindDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'nameKind', Sort.desc);
    });
  }

  QueryBuilder<WordCollection, WordCollection, QAfterSortBy> sortByOrder() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'order', Sort.asc);
    });
  }

  QueryBuilder<WordCollection, WordCollection, QAfterSortBy> sortByOrderDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'order', Sort.desc);
    });
  }

  QueryBuilder<WordCollection, WordCollection, QAfterSortBy>
      sortByPublishedId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'publishedId', Sort.asc);
    });
  }

  QueryBuilder<WordCollection, WordCollection, QAfterSortBy>
      sortByPublishedIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'publishedId', Sort.desc);
    });
  }

  QueryBuilder<WordCollection, WordCollection, QAfterSortBy>
      sortBySelectedGroupId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'selectedGroupId', Sort.asc);
    });
  }

  QueryBuilder<WordCollection, WordCollection, QAfterSortBy>
      sortBySelectedGroupIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'selectedGroupId', Sort.desc);
    });
  }

  QueryBuilder<WordCollection, WordCollection, QAfterSortBy>
      sortByCollectionId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sessionId', Sort.asc);
    });
  }

  QueryBuilder<WordCollection, WordCollection, QAfterSortBy>
      sortByCollectionIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sessionId', Sort.desc);
    });
  }

  QueryBuilder<WordCollection, WordCollection, QAfterSortBy> sortByUpdatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAt', Sort.asc);
    });
  }

  QueryBuilder<WordCollection, WordCollection, QAfterSortBy>
      sortByUpdatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAt', Sort.desc);
    });
  }
}

extension WordCollectionQuerySortThenBy
    on QueryBuilder<WordCollection, WordCollection, QSortThenBy> {
  QueryBuilder<WordCollection, WordCollection, QAfterSortBy> thenByBinnedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'binnedAt', Sort.asc);
    });
  }

  QueryBuilder<WordCollection, WordCollection, QAfterSortBy>
      thenByBinnedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'binnedAt', Sort.desc);
    });
  }

  QueryBuilder<WordCollection, WordCollection, QAfterSortBy>
      thenByBinnedFromFolderId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'binnedFromFolderId', Sort.asc);
    });
  }

  QueryBuilder<WordCollection, WordCollection, QAfterSortBy>
      thenByBinnedFromFolderIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'binnedFromFolderId', Sort.desc);
    });
  }

  QueryBuilder<WordCollection, WordCollection, QAfterSortBy>
      thenByDescription() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'description', Sort.asc);
    });
  }

  QueryBuilder<WordCollection, WordCollection, QAfterSortBy>
      thenByDescriptionDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'description', Sort.desc);
    });
  }

  QueryBuilder<WordCollection, WordCollection, QAfterSortBy>
      thenByDescriptionKind() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'descriptionKind', Sort.asc);
    });
  }

  QueryBuilder<WordCollection, WordCollection, QAfterSortBy>
      thenByDescriptionKindDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'descriptionKind', Sort.desc);
    });
  }

  QueryBuilder<WordCollection, WordCollection, QAfterSortBy> thenByEditToken() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'editToken', Sort.asc);
    });
  }

  QueryBuilder<WordCollection, WordCollection, QAfterSortBy>
      thenByEditTokenDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'editToken', Sort.desc);
    });
  }

  QueryBuilder<WordCollection, WordCollection, QAfterSortBy> thenByFolderId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'folderId', Sort.asc);
    });
  }

  QueryBuilder<WordCollection, WordCollection, QAfterSortBy>
      thenByFolderIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'folderId', Sort.desc);
    });
  }

  QueryBuilder<WordCollection, WordCollection, QAfterSortBy>
      thenByGroupedWordsKey() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'groupedWordsKey', Sort.asc);
    });
  }

  QueryBuilder<WordCollection, WordCollection, QAfterSortBy>
      thenByGroupedWordsKeyDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'groupedWordsKey', Sort.desc);
    });
  }

  QueryBuilder<WordCollection, WordCollection, QAfterSortBy> thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<WordCollection, WordCollection, QAfterSortBy> thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<WordCollection, WordCollection, QAfterSortBy> thenByIsShared() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isShared', Sort.asc);
    });
  }

  QueryBuilder<WordCollection, WordCollection, QAfterSortBy>
      thenByIsSharedDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isShared', Sort.desc);
    });
  }

  QueryBuilder<WordCollection, WordCollection, QAfterSortBy> thenByKeep() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'keep', Sort.asc);
    });
  }

  QueryBuilder<WordCollection, WordCollection, QAfterSortBy> thenByKeepDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'keep', Sort.desc);
    });
  }

  QueryBuilder<WordCollection, WordCollection, QAfterSortBy>
      thenByLastLocalModifiedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastLocalModifiedAt', Sort.asc);
    });
  }

  QueryBuilder<WordCollection, WordCollection, QAfterSortBy>
      thenByLastLocalModifiedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastLocalModifiedAt', Sort.desc);
    });
  }

  QueryBuilder<WordCollection, WordCollection, QAfterSortBy> thenByName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'name', Sort.asc);
    });
  }

  QueryBuilder<WordCollection, WordCollection, QAfterSortBy> thenByNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'name', Sort.desc);
    });
  }

  QueryBuilder<WordCollection, WordCollection, QAfterSortBy> thenByNameKind() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'nameKind', Sort.asc);
    });
  }

  QueryBuilder<WordCollection, WordCollection, QAfterSortBy>
      thenByNameKindDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'nameKind', Sort.desc);
    });
  }

  QueryBuilder<WordCollection, WordCollection, QAfterSortBy> thenByOrder() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'order', Sort.asc);
    });
  }

  QueryBuilder<WordCollection, WordCollection, QAfterSortBy> thenByOrderDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'order', Sort.desc);
    });
  }

  QueryBuilder<WordCollection, WordCollection, QAfterSortBy>
      thenByPublishedId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'publishedId', Sort.asc);
    });
  }

  QueryBuilder<WordCollection, WordCollection, QAfterSortBy>
      thenByPublishedIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'publishedId', Sort.desc);
    });
  }

  QueryBuilder<WordCollection, WordCollection, QAfterSortBy>
      thenBySelectedGroupId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'selectedGroupId', Sort.asc);
    });
  }

  QueryBuilder<WordCollection, WordCollection, QAfterSortBy>
      thenBySelectedGroupIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'selectedGroupId', Sort.desc);
    });
  }

  QueryBuilder<WordCollection, WordCollection, QAfterSortBy>
      thenByCollectionId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sessionId', Sort.asc);
    });
  }

  QueryBuilder<WordCollection, WordCollection, QAfterSortBy>
      thenByCollectionIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sessionId', Sort.desc);
    });
  }

  QueryBuilder<WordCollection, WordCollection, QAfterSortBy> thenByUpdatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAt', Sort.asc);
    });
  }

  QueryBuilder<WordCollection, WordCollection, QAfterSortBy>
      thenByUpdatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAt', Sort.desc);
    });
  }
}

extension WordCollectionQueryWhereDistinct
    on QueryBuilder<WordCollection, WordCollection, QDistinct> {
  QueryBuilder<WordCollection, WordCollection, QDistinct> distinctByBinnedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'binnedAt');
    });
  }

  QueryBuilder<WordCollection, WordCollection, QDistinct>
      distinctByBinnedFromFolderId({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'binnedFromFolderId',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<WordCollection, WordCollection, QDistinct> distinctByDescription(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'description', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<WordCollection, WordCollection, QDistinct>
      distinctByDescriptionKind() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'descriptionKind');
    });
  }

  QueryBuilder<WordCollection, WordCollection, QDistinct> distinctByEditToken(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'editToken', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<WordCollection, WordCollection, QDistinct> distinctByFolderId(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'folderId', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<WordCollection, WordCollection, QDistinct>
      distinctByGroupedWordsKey({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'groupedWordsKey',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<WordCollection, WordCollection, QDistinct> distinctByIsShared() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'isShared');
    });
  }

  QueryBuilder<WordCollection, WordCollection, QDistinct> distinctByKeep() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'keep');
    });
  }

  QueryBuilder<WordCollection, WordCollection, QDistinct>
      distinctByLastLocalModifiedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'lastLocalModifiedAt');
    });
  }

  QueryBuilder<WordCollection, WordCollection, QDistinct> distinctByName(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'name', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<WordCollection, WordCollection, QDistinct> distinctByNameKind() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'nameKind');
    });
  }

  QueryBuilder<WordCollection, WordCollection, QDistinct> distinctByOrder() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'order');
    });
  }

  QueryBuilder<WordCollection, WordCollection, QDistinct>
      distinctByOriginTags() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'originTags');
    });
  }

  QueryBuilder<WordCollection, WordCollection, QDistinct> distinctByPublishedId(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'publishedId', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<WordCollection, WordCollection, QDistinct>
      distinctBySelectedGroupId({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'selectedGroupId',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<WordCollection, WordCollection, QDistinct>
      distinctByCollectionId({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'sessionId', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<WordCollection, WordCollection, QDistinct> distinctByTags() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'tags');
    });
  }

  QueryBuilder<WordCollection, WordCollection, QDistinct>
      distinctByTopicTags() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'topicTags');
    });
  }

  QueryBuilder<WordCollection, WordCollection, QDistinct>
      distinctByUpdatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'updatedAt');
    });
  }
}

extension WordCollectionQueryProperty
    on QueryBuilder<WordCollection, WordCollection, QQueryProperty> {
  QueryBuilder<WordCollection, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<WordCollection, DateTime?, QQueryOperations> binnedAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'binnedAt');
    });
  }

  QueryBuilder<WordCollection, String?, QQueryOperations>
      binnedFromFolderIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'binnedFromFolderId');
    });
  }

  QueryBuilder<WordCollection, List<WordBox>, QQueryOperations>
      boxesProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'boxes');
    });
  }

  QueryBuilder<WordCollection, String?, QQueryOperations>
      descriptionProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'description');
    });
  }

  QueryBuilder<WordCollection, NameKind, QQueryOperations>
      descriptionKindProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'descriptionKind');
    });
  }

  QueryBuilder<WordCollection, List<FilmDialogue>, QQueryOperations>
      dialoguesProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'dialogues');
    });
  }

  QueryBuilder<WordCollection, String?, QQueryOperations> editTokenProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'editToken');
    });
  }

  QueryBuilder<WordCollection, String?, QQueryOperations> folderIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'folderId');
    });
  }

  QueryBuilder<WordCollection, String?, QQueryOperations>
      groupedWordsKeyProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'groupedWordsKey');
    });
  }

  QueryBuilder<WordCollection, List<WordGroup>, QQueryOperations>
      groupsProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'groups');
    });
  }

  QueryBuilder<WordCollection, bool, QQueryOperations> isSharedProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'isShared');
    });
  }

  QueryBuilder<WordCollection, bool, QQueryOperations> keepProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'keep');
    });
  }

  QueryBuilder<WordCollection, DateTime, QQueryOperations>
      lastLocalModifiedAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'lastLocalModifiedAt');
    });
  }

  QueryBuilder<WordCollection, String?, QQueryOperations> nameProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'name');
    });
  }

  QueryBuilder<WordCollection, NameKind, QQueryOperations> nameKindProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'nameKind');
    });
  }

  QueryBuilder<WordCollection, int, QQueryOperations> orderProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'order');
    });
  }

  QueryBuilder<WordCollection, List<String>, QQueryOperations>
      originTagsProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'originTags');
    });
  }

  QueryBuilder<WordCollection, String?, QQueryOperations>
      publishedIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'publishedId');
    });
  }

  QueryBuilder<WordCollection, List<WordResult>, QQueryOperations>
      resultsProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'results');
    });
  }

  QueryBuilder<WordCollection, String?, QQueryOperations>
      selectedGroupIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'selectedGroupId');
    });
  }

  QueryBuilder<WordCollection, String, QQueryOperations>
      collectionIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'sessionId');
    });
  }

  QueryBuilder<WordCollection, List<SessionSource>, QQueryOperations>
      sourcesProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'sources');
    });
  }

  QueryBuilder<WordCollection, List<String>, QQueryOperations> tagsProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'tags');
    });
  }

  QueryBuilder<WordCollection, List<String>, QQueryOperations>
      topicTagsProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'topicTags');
    });
  }

  QueryBuilder<WordCollection, DateTime, QQueryOperations> updatedAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'updatedAt');
    });
  }

  QueryBuilder<WordCollection, List<WordPair>, QQueryOperations>
      wordsProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'words');
    });
  }
}
