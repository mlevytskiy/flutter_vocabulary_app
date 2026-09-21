// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'session.dart';

// **************************************************************************
// IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetSessionCollection on Isar {
  IsarCollection<Session> get sessions => this.collection();
}

const SessionSchema = CollectionSchema(
  name: r'Session',
  id: 4817823809690647594,
  properties: {
    r'isShared': PropertySchema(
      id: 0,
      name: r'isShared',
      type: IsarType.bool,
    ),
    r'lastLocalModifiedAt': PropertySchema(
      id: 1,
      name: r'lastLocalModifiedAt',
      type: IsarType.dateTime,
    ),
    r'sessionId': PropertySchema(
      id: 2,
      name: r'sessionId',
      type: IsarType.string,
    ),
    r'updatedAt': PropertySchema(
      id: 3,
      name: r'updatedAt',
      type: IsarType.dateTime,
    ),
    r'words': PropertySchema(
      id: 4,
      name: r'words',
      type: IsarType.objectList,
      target: r'WordPair',
    )
  },
  estimateSize: _sessionEstimateSize,
  serialize: _sessionSerialize,
  deserialize: _sessionDeserialize,
  deserializeProp: _sessionDeserializeProp,
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
    )
  },
  links: {},
  embeddedSchemas: {r'WordPair': WordPairSchema},
  getId: _sessionGetId,
  getLinks: _sessionGetLinks,
  attach: _sessionAttach,
  version: '3.3.0-dev.1',
);

int _sessionEstimateSize(
  Session object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  bytesCount += 3 + object.sessionId.length * 3;
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

void _sessionSerialize(
  Session object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeBool(offsets[0], object.isShared);
  writer.writeDateTime(offsets[1], object.lastLocalModifiedAt);
  writer.writeString(offsets[2], object.sessionId);
  writer.writeDateTime(offsets[3], object.updatedAt);
  writer.writeObjectList<WordPair>(
    offsets[4],
    allOffsets,
    WordPairSchema.serialize,
    object.words,
  );
}

Session _sessionDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = Session();
  object.id = id;
  object.isShared = reader.readBool(offsets[0]);
  object.lastLocalModifiedAt = reader.readDateTime(offsets[1]);
  object.sessionId = reader.readString(offsets[2]);
  object.updatedAt = reader.readDateTime(offsets[3]);
  object.words = reader.readObjectList<WordPair>(
        offsets[4],
        WordPairSchema.deserialize,
        allOffsets,
        WordPair(),
      ) ??
      [];
  return object;
}

P _sessionDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readBool(offset)) as P;
    case 1:
      return (reader.readDateTime(offset)) as P;
    case 2:
      return (reader.readString(offset)) as P;
    case 3:
      return (reader.readDateTime(offset)) as P;
    case 4:
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

Id _sessionGetId(Session object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _sessionGetLinks(Session object) {
  return [];
}

void _sessionAttach(IsarCollection<dynamic> col, Id id, Session object) {
  object.id = id;
}

extension SessionByIndex on IsarCollection<Session> {
  Future<Session?> getBySessionId(String sessionId) {
    return getByIndex(r'sessionId', [sessionId]);
  }

  Session? getBySessionIdSync(String sessionId) {
    return getByIndexSync(r'sessionId', [sessionId]);
  }

  Future<bool> deleteBySessionId(String sessionId) {
    return deleteByIndex(r'sessionId', [sessionId]);
  }

  bool deleteBySessionIdSync(String sessionId) {
    return deleteByIndexSync(r'sessionId', [sessionId]);
  }

  Future<List<Session?>> getAllBySessionId(List<String> sessionIdValues) {
    final values = sessionIdValues.map((e) => [e]).toList();
    return getAllByIndex(r'sessionId', values);
  }

  List<Session?> getAllBySessionIdSync(List<String> sessionIdValues) {
    final values = sessionIdValues.map((e) => [e]).toList();
    return getAllByIndexSync(r'sessionId', values);
  }

  Future<int> deleteAllBySessionId(List<String> sessionIdValues) {
    final values = sessionIdValues.map((e) => [e]).toList();
    return deleteAllByIndex(r'sessionId', values);
  }

  int deleteAllBySessionIdSync(List<String> sessionIdValues) {
    final values = sessionIdValues.map((e) => [e]).toList();
    return deleteAllByIndexSync(r'sessionId', values);
  }

  Future<Id> putBySessionId(Session object) {
    return putByIndex(r'sessionId', object);
  }

  Id putBySessionIdSync(Session object, {bool saveLinks = true}) {
    return putByIndexSync(r'sessionId', object, saveLinks: saveLinks);
  }

  Future<List<Id>> putAllBySessionId(List<Session> objects) {
    return putAllByIndex(r'sessionId', objects);
  }

  List<Id> putAllBySessionIdSync(List<Session> objects,
      {bool saveLinks = true}) {
    return putAllByIndexSync(r'sessionId', objects, saveLinks: saveLinks);
  }
}

extension SessionQueryWhereSort on QueryBuilder<Session, Session, QWhere> {
  QueryBuilder<Session, Session, QAfterWhere> anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }
}

extension SessionQueryWhere on QueryBuilder<Session, Session, QWhereClause> {
  QueryBuilder<Session, Session, QAfterWhereClause> idEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(
        lower: id,
        upper: id,
      ));
    });
  }

  QueryBuilder<Session, Session, QAfterWhereClause> idNotEqualTo(Id id) {
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

  QueryBuilder<Session, Session, QAfterWhereClause> idGreaterThan(Id id,
      {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<Session, Session, QAfterWhereClause> idLessThan(Id id,
      {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<Session, Session, QAfterWhereClause> idBetween(
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

  QueryBuilder<Session, Session, QAfterWhereClause> sessionIdEqualTo(
      String sessionId) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'sessionId',
        value: [sessionId],
      ));
    });
  }

  QueryBuilder<Session, Session, QAfterWhereClause> sessionIdNotEqualTo(
      String sessionId) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'sessionId',
              lower: [],
              upper: [sessionId],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'sessionId',
              lower: [sessionId],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'sessionId',
              lower: [sessionId],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'sessionId',
              lower: [],
              upper: [sessionId],
              includeUpper: false,
            ));
      }
    });
  }
}

extension SessionQueryFilter
    on QueryBuilder<Session, Session, QFilterCondition> {
  QueryBuilder<Session, Session, QAfterFilterCondition> idEqualTo(Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<Session, Session, QAfterFilterCondition> idGreaterThan(
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

  QueryBuilder<Session, Session, QAfterFilterCondition> idLessThan(
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

  QueryBuilder<Session, Session, QAfterFilterCondition> idBetween(
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

  QueryBuilder<Session, Session, QAfterFilterCondition> isSharedEqualTo(
      bool value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'isShared',
        value: value,
      ));
    });
  }

  QueryBuilder<Session, Session, QAfterFilterCondition>
      lastLocalModifiedAtEqualTo(DateTime value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'lastLocalModifiedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<Session, Session, QAfterFilterCondition>
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

  QueryBuilder<Session, Session, QAfterFilterCondition>
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

  QueryBuilder<Session, Session, QAfterFilterCondition>
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

  QueryBuilder<Session, Session, QAfterFilterCondition> sessionIdEqualTo(
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

  QueryBuilder<Session, Session, QAfterFilterCondition> sessionIdGreaterThan(
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

  QueryBuilder<Session, Session, QAfterFilterCondition> sessionIdLessThan(
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

  QueryBuilder<Session, Session, QAfterFilterCondition> sessionIdBetween(
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

  QueryBuilder<Session, Session, QAfterFilterCondition> sessionIdStartsWith(
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

  QueryBuilder<Session, Session, QAfterFilterCondition> sessionIdEndsWith(
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

  QueryBuilder<Session, Session, QAfterFilterCondition> sessionIdContains(
      String value,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'sessionId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Session, Session, QAfterFilterCondition> sessionIdMatches(
      String pattern,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'sessionId',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<Session, Session, QAfterFilterCondition> sessionIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'sessionId',
        value: '',
      ));
    });
  }

  QueryBuilder<Session, Session, QAfterFilterCondition> sessionIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'sessionId',
        value: '',
      ));
    });
  }

  QueryBuilder<Session, Session, QAfterFilterCondition> updatedAtEqualTo(
      DateTime value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'updatedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<Session, Session, QAfterFilterCondition> updatedAtGreaterThan(
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

  QueryBuilder<Session, Session, QAfterFilterCondition> updatedAtLessThan(
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

  QueryBuilder<Session, Session, QAfterFilterCondition> updatedAtBetween(
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

  QueryBuilder<Session, Session, QAfterFilterCondition> wordsLengthEqualTo(
      int length) {
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

  QueryBuilder<Session, Session, QAfterFilterCondition> wordsIsEmpty() {
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

  QueryBuilder<Session, Session, QAfterFilterCondition> wordsIsNotEmpty() {
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

  QueryBuilder<Session, Session, QAfterFilterCondition> wordsLengthLessThan(
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

  QueryBuilder<Session, Session, QAfterFilterCondition> wordsLengthGreaterThan(
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

  QueryBuilder<Session, Session, QAfterFilterCondition> wordsLengthBetween(
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

extension SessionQueryObject
    on QueryBuilder<Session, Session, QFilterCondition> {
  QueryBuilder<Session, Session, QAfterFilterCondition> wordsElement(
      FilterQuery<WordPair> q) {
    return QueryBuilder.apply(this, (query) {
      return query.object(q, r'words');
    });
  }
}

extension SessionQueryLinks
    on QueryBuilder<Session, Session, QFilterCondition> {}

extension SessionQuerySortBy on QueryBuilder<Session, Session, QSortBy> {
  QueryBuilder<Session, Session, QAfterSortBy> sortByIsShared() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isShared', Sort.asc);
    });
  }

  QueryBuilder<Session, Session, QAfterSortBy> sortByIsSharedDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isShared', Sort.desc);
    });
  }

  QueryBuilder<Session, Session, QAfterSortBy> sortByLastLocalModifiedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastLocalModifiedAt', Sort.asc);
    });
  }

  QueryBuilder<Session, Session, QAfterSortBy> sortByLastLocalModifiedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastLocalModifiedAt', Sort.desc);
    });
  }

  QueryBuilder<Session, Session, QAfterSortBy> sortBySessionId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sessionId', Sort.asc);
    });
  }

  QueryBuilder<Session, Session, QAfterSortBy> sortBySessionIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sessionId', Sort.desc);
    });
  }

  QueryBuilder<Session, Session, QAfterSortBy> sortByUpdatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAt', Sort.asc);
    });
  }

  QueryBuilder<Session, Session, QAfterSortBy> sortByUpdatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAt', Sort.desc);
    });
  }
}

extension SessionQuerySortThenBy
    on QueryBuilder<Session, Session, QSortThenBy> {
  QueryBuilder<Session, Session, QAfterSortBy> thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<Session, Session, QAfterSortBy> thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<Session, Session, QAfterSortBy> thenByIsShared() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isShared', Sort.asc);
    });
  }

  QueryBuilder<Session, Session, QAfterSortBy> thenByIsSharedDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isShared', Sort.desc);
    });
  }

  QueryBuilder<Session, Session, QAfterSortBy> thenByLastLocalModifiedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastLocalModifiedAt', Sort.asc);
    });
  }

  QueryBuilder<Session, Session, QAfterSortBy> thenByLastLocalModifiedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastLocalModifiedAt', Sort.desc);
    });
  }

  QueryBuilder<Session, Session, QAfterSortBy> thenBySessionId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sessionId', Sort.asc);
    });
  }

  QueryBuilder<Session, Session, QAfterSortBy> thenBySessionIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'sessionId', Sort.desc);
    });
  }

  QueryBuilder<Session, Session, QAfterSortBy> thenByUpdatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAt', Sort.asc);
    });
  }

  QueryBuilder<Session, Session, QAfterSortBy> thenByUpdatedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'updatedAt', Sort.desc);
    });
  }
}

extension SessionQueryWhereDistinct
    on QueryBuilder<Session, Session, QDistinct> {
  QueryBuilder<Session, Session, QDistinct> distinctByIsShared() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'isShared');
    });
  }

  QueryBuilder<Session, Session, QDistinct> distinctByLastLocalModifiedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'lastLocalModifiedAt');
    });
  }

  QueryBuilder<Session, Session, QDistinct> distinctBySessionId(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'sessionId', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<Session, Session, QDistinct> distinctByUpdatedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'updatedAt');
    });
  }
}

extension SessionQueryProperty
    on QueryBuilder<Session, Session, QQueryProperty> {
  QueryBuilder<Session, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<Session, bool, QQueryOperations> isSharedProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'isShared');
    });
  }

  QueryBuilder<Session, DateTime, QQueryOperations>
      lastLocalModifiedAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'lastLocalModifiedAt');
    });
  }

  QueryBuilder<Session, String, QQueryOperations> sessionIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'sessionId');
    });
  }

  QueryBuilder<Session, DateTime, QQueryOperations> updatedAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'updatedAt');
    });
  }

  QueryBuilder<Session, List<WordPair>, QQueryOperations> wordsProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'words');
    });
  }
}
