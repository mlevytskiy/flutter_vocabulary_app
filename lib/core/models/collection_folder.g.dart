// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'collection_folder.dart';

// **************************************************************************
// IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetCollectionFolderCollection on Isar {
  IsarCollection<CollectionFolder> get collectionFolders => this.collection();
}

const CollectionFolderSchema = CollectionSchema(
  name: r'CollectionFolder',
  id: -819284268557997043,
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
    r'folderId': PropertySchema(
      id: 2,
      name: r'folderId',
      type: IsarType.string,
    ),
    r'name': PropertySchema(
      id: 3,
      name: r'name',
      type: IsarType.string,
    ),
    r'order': PropertySchema(
      id: 4,
      name: r'order',
      type: IsarType.long,
    ),
    r'parentId': PropertySchema(
      id: 5,
      name: r'parentId',
      type: IsarType.string,
    )
  },
  estimateSize: _collectionFolderEstimateSize,
  serialize: _collectionFolderSerialize,
  deserialize: _collectionFolderDeserialize,
  deserializeProp: _collectionFolderDeserializeProp,
  idName: r'id',
  indexes: {
    r'folderId': IndexSchema(
      id: 6340065978996931043,
      name: r'folderId',
      unique: true,
      replace: true,
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
  embeddedSchemas: {},
  getId: _collectionFolderGetId,
  getLinks: _collectionFolderGetLinks,
  attach: _collectionFolderAttach,
  version: '3.3.0-dev.1',
);

int _collectionFolderEstimateSize(
  CollectionFolder object,
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
  bytesCount += 3 + object.folderId.length * 3;
  bytesCount += 3 + object.name.length * 3;
  {
    final value = object.parentId;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  return bytesCount;
}

void _collectionFolderSerialize(
  CollectionFolder object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeDateTime(offsets[0], object.binnedAt);
  writer.writeString(offsets[1], object.binnedFromFolderId);
  writer.writeString(offsets[2], object.folderId);
  writer.writeString(offsets[3], object.name);
  writer.writeLong(offsets[4], object.order);
  writer.writeString(offsets[5], object.parentId);
}

CollectionFolder _collectionFolderDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = CollectionFolder();
  object.binnedAt = reader.readDateTimeOrNull(offsets[0]);
  object.binnedFromFolderId = reader.readStringOrNull(offsets[1]);
  object.folderId = reader.readString(offsets[2]);
  object.id = id;
  object.name = reader.readString(offsets[3]);
  object.order = reader.readLong(offsets[4]);
  object.parentId = reader.readStringOrNull(offsets[5]);
  return object;
}

P _collectionFolderDeserializeProp<P>(
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
      return (reader.readString(offset)) as P;
    case 3:
      return (reader.readString(offset)) as P;
    case 4:
      return (reader.readLong(offset)) as P;
    case 5:
      return (reader.readStringOrNull(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _collectionFolderGetId(CollectionFolder object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _collectionFolderGetLinks(CollectionFolder object) {
  return [];
}

void _collectionFolderAttach(
    IsarCollection<dynamic> col, Id id, CollectionFolder object) {
  object.id = id;
}

extension CollectionFolderByIndex on IsarCollection<CollectionFolder> {
  Future<CollectionFolder?> getByFolderId(String folderId) {
    return getByIndex(r'folderId', [folderId]);
  }

  CollectionFolder? getByFolderIdSync(String folderId) {
    return getByIndexSync(r'folderId', [folderId]);
  }

  Future<bool> deleteByFolderId(String folderId) {
    return deleteByIndex(r'folderId', [folderId]);
  }

  bool deleteByFolderIdSync(String folderId) {
    return deleteByIndexSync(r'folderId', [folderId]);
  }

  Future<List<CollectionFolder?>> getAllByFolderId(
      List<String> folderIdValues) {
    final values = folderIdValues.map((e) => [e]).toList();
    return getAllByIndex(r'folderId', values);
  }

  List<CollectionFolder?> getAllByFolderIdSync(List<String> folderIdValues) {
    final values = folderIdValues.map((e) => [e]).toList();
    return getAllByIndexSync(r'folderId', values);
  }

  Future<int> deleteAllByFolderId(List<String> folderIdValues) {
    final values = folderIdValues.map((e) => [e]).toList();
    return deleteAllByIndex(r'folderId', values);
  }

  int deleteAllByFolderIdSync(List<String> folderIdValues) {
    final values = folderIdValues.map((e) => [e]).toList();
    return deleteAllByIndexSync(r'folderId', values);
  }

  Future<Id> putByFolderId(CollectionFolder object) {
    return putByIndex(r'folderId', object);
  }

  Id putByFolderIdSync(CollectionFolder object, {bool saveLinks = true}) {
    return putByIndexSync(r'folderId', object, saveLinks: saveLinks);
  }

  Future<List<Id>> putAllByFolderId(List<CollectionFolder> objects) {
    return putAllByIndex(r'folderId', objects);
  }

  List<Id> putAllByFolderIdSync(List<CollectionFolder> objects,
      {bool saveLinks = true}) {
    return putAllByIndexSync(r'folderId', objects, saveLinks: saveLinks);
  }
}

extension CollectionFolderQueryWhereSort
    on QueryBuilder<CollectionFolder, CollectionFolder, QWhere> {
  QueryBuilder<CollectionFolder, CollectionFolder, QAfterWhere> anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }

  QueryBuilder<CollectionFolder, CollectionFolder, QAfterWhere> anyBinnedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        const IndexWhereClause.any(indexName: r'binnedAt'),
      );
    });
  }
}

extension CollectionFolderQueryWhere
    on QueryBuilder<CollectionFolder, CollectionFolder, QWhereClause> {
  QueryBuilder<CollectionFolder, CollectionFolder, QAfterWhereClause> idEqualTo(
      Id id) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(
        lower: id,
        upper: id,
      ));
    });
  }

  QueryBuilder<CollectionFolder, CollectionFolder, QAfterWhereClause>
      idNotEqualTo(Id id) {
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

  QueryBuilder<CollectionFolder, CollectionFolder, QAfterWhereClause>
      idGreaterThan(Id id, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<CollectionFolder, CollectionFolder, QAfterWhereClause>
      idLessThan(Id id, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<CollectionFolder, CollectionFolder, QAfterWhereClause> idBetween(
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

  QueryBuilder<CollectionFolder, CollectionFolder, QAfterWhereClause>
      folderIdEqualTo(String folderId) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'folderId',
        value: [folderId],
      ));
    });
  }

  QueryBuilder<CollectionFolder, CollectionFolder, QAfterWhereClause>
      folderIdNotEqualTo(String folderId) {
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

  QueryBuilder<CollectionFolder, CollectionFolder, QAfterWhereClause>
      binnedAtIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'binnedAt',
        value: [null],
      ));
    });
  }

  QueryBuilder<CollectionFolder, CollectionFolder, QAfterWhereClause>
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

  QueryBuilder<CollectionFolder, CollectionFolder, QAfterWhereClause>
      binnedAtEqualTo(DateTime? binnedAt) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'binnedAt',
        value: [binnedAt],
      ));
    });
  }

  QueryBuilder<CollectionFolder, CollectionFolder, QAfterWhereClause>
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

  QueryBuilder<CollectionFolder, CollectionFolder, QAfterWhereClause>
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

  QueryBuilder<CollectionFolder, CollectionFolder, QAfterWhereClause>
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

  QueryBuilder<CollectionFolder, CollectionFolder, QAfterWhereClause>
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

extension CollectionFolderQueryFilter
    on QueryBuilder<CollectionFolder, CollectionFolder, QFilterCondition> {
  QueryBuilder<CollectionFolder, CollectionFolder, QAfterFilterCondition>
      binnedAtIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'binnedAt',
      ));
    });
  }

  QueryBuilder<CollectionFolder, CollectionFolder, QAfterFilterCondition>
      binnedAtIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'binnedAt',
      ));
    });
  }

  QueryBuilder<CollectionFolder, CollectionFolder, QAfterFilterCondition>
      binnedAtEqualTo(DateTime? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'binnedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<CollectionFolder, CollectionFolder, QAfterFilterCondition>
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

  QueryBuilder<CollectionFolder, CollectionFolder, QAfterFilterCondition>
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

  QueryBuilder<CollectionFolder, CollectionFolder, QAfterFilterCondition>
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

  QueryBuilder<CollectionFolder, CollectionFolder, QAfterFilterCondition>
      binnedFromFolderIdIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'binnedFromFolderId',
      ));
    });
  }

  QueryBuilder<CollectionFolder, CollectionFolder, QAfterFilterCondition>
      binnedFromFolderIdIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'binnedFromFolderId',
      ));
    });
  }

  QueryBuilder<CollectionFolder, CollectionFolder, QAfterFilterCondition>
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

  QueryBuilder<CollectionFolder, CollectionFolder, QAfterFilterCondition>
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

  QueryBuilder<CollectionFolder, CollectionFolder, QAfterFilterCondition>
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

  QueryBuilder<CollectionFolder, CollectionFolder, QAfterFilterCondition>
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

  QueryBuilder<CollectionFolder, CollectionFolder, QAfterFilterCondition>
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

  QueryBuilder<CollectionFolder, CollectionFolder, QAfterFilterCondition>
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

  QueryBuilder<CollectionFolder, CollectionFolder, QAfterFilterCondition>
      binnedFromFolderIdContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'binnedFromFolderId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<CollectionFolder, CollectionFolder, QAfterFilterCondition>
      binnedFromFolderIdMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'binnedFromFolderId',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<CollectionFolder, CollectionFolder, QAfterFilterCondition>
      binnedFromFolderIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'binnedFromFolderId',
        value: '',
      ));
    });
  }

  QueryBuilder<CollectionFolder, CollectionFolder, QAfterFilterCondition>
      binnedFromFolderIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'binnedFromFolderId',
        value: '',
      ));
    });
  }

  QueryBuilder<CollectionFolder, CollectionFolder, QAfterFilterCondition>
      folderIdEqualTo(
    String value, {
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

  QueryBuilder<CollectionFolder, CollectionFolder, QAfterFilterCondition>
      folderIdGreaterThan(
    String value, {
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

  QueryBuilder<CollectionFolder, CollectionFolder, QAfterFilterCondition>
      folderIdLessThan(
    String value, {
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

  QueryBuilder<CollectionFolder, CollectionFolder, QAfterFilterCondition>
      folderIdBetween(
    String lower,
    String upper, {
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

  QueryBuilder<CollectionFolder, CollectionFolder, QAfterFilterCondition>
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

  QueryBuilder<CollectionFolder, CollectionFolder, QAfterFilterCondition>
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

  QueryBuilder<CollectionFolder, CollectionFolder, QAfterFilterCondition>
      folderIdContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'folderId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<CollectionFolder, CollectionFolder, QAfterFilterCondition>
      folderIdMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'folderId',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<CollectionFolder, CollectionFolder, QAfterFilterCondition>
      folderIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'folderId',
        value: '',
      ));
    });
  }

  QueryBuilder<CollectionFolder, CollectionFolder, QAfterFilterCondition>
      folderIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'folderId',
        value: '',
      ));
    });
  }

  QueryBuilder<CollectionFolder, CollectionFolder, QAfterFilterCondition>
      idEqualTo(Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<CollectionFolder, CollectionFolder, QAfterFilterCondition>
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

  QueryBuilder<CollectionFolder, CollectionFolder, QAfterFilterCondition>
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

  QueryBuilder<CollectionFolder, CollectionFolder, QAfterFilterCondition>
      idBetween(
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

  QueryBuilder<CollectionFolder, CollectionFolder, QAfterFilterCondition>
      nameEqualTo(
    String value, {
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

  QueryBuilder<CollectionFolder, CollectionFolder, QAfterFilterCondition>
      nameGreaterThan(
    String value, {
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

  QueryBuilder<CollectionFolder, CollectionFolder, QAfterFilterCondition>
      nameLessThan(
    String value, {
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

  QueryBuilder<CollectionFolder, CollectionFolder, QAfterFilterCondition>
      nameBetween(
    String lower,
    String upper, {
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

  QueryBuilder<CollectionFolder, CollectionFolder, QAfterFilterCondition>
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

  QueryBuilder<CollectionFolder, CollectionFolder, QAfterFilterCondition>
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

  QueryBuilder<CollectionFolder, CollectionFolder, QAfterFilterCondition>
      nameContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'name',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<CollectionFolder, CollectionFolder, QAfterFilterCondition>
      nameMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'name',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<CollectionFolder, CollectionFolder, QAfterFilterCondition>
      nameIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'name',
        value: '',
      ));
    });
  }

  QueryBuilder<CollectionFolder, CollectionFolder, QAfterFilterCondition>
      nameIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'name',
        value: '',
      ));
    });
  }

  QueryBuilder<CollectionFolder, CollectionFolder, QAfterFilterCondition>
      orderEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'order',
        value: value,
      ));
    });
  }

  QueryBuilder<CollectionFolder, CollectionFolder, QAfterFilterCondition>
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

  QueryBuilder<CollectionFolder, CollectionFolder, QAfterFilterCondition>
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

  QueryBuilder<CollectionFolder, CollectionFolder, QAfterFilterCondition>
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

  QueryBuilder<CollectionFolder, CollectionFolder, QAfterFilterCondition>
      parentIdIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'parentId',
      ));
    });
  }

  QueryBuilder<CollectionFolder, CollectionFolder, QAfterFilterCondition>
      parentIdIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'parentId',
      ));
    });
  }

  QueryBuilder<CollectionFolder, CollectionFolder, QAfterFilterCondition>
      parentIdEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'parentId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<CollectionFolder, CollectionFolder, QAfterFilterCondition>
      parentIdGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'parentId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<CollectionFolder, CollectionFolder, QAfterFilterCondition>
      parentIdLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'parentId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<CollectionFolder, CollectionFolder, QAfterFilterCondition>
      parentIdBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'parentId',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<CollectionFolder, CollectionFolder, QAfterFilterCondition>
      parentIdStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'parentId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<CollectionFolder, CollectionFolder, QAfterFilterCondition>
      parentIdEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'parentId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<CollectionFolder, CollectionFolder, QAfterFilterCondition>
      parentIdContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'parentId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<CollectionFolder, CollectionFolder, QAfterFilterCondition>
      parentIdMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'parentId',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<CollectionFolder, CollectionFolder, QAfterFilterCondition>
      parentIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'parentId',
        value: '',
      ));
    });
  }

  QueryBuilder<CollectionFolder, CollectionFolder, QAfterFilterCondition>
      parentIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'parentId',
        value: '',
      ));
    });
  }
}

extension CollectionFolderQueryObject
    on QueryBuilder<CollectionFolder, CollectionFolder, QFilterCondition> {}

extension CollectionFolderQueryLinks
    on QueryBuilder<CollectionFolder, CollectionFolder, QFilterCondition> {}

extension CollectionFolderQuerySortBy
    on QueryBuilder<CollectionFolder, CollectionFolder, QSortBy> {
  QueryBuilder<CollectionFolder, CollectionFolder, QAfterSortBy>
      sortByBinnedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'binnedAt', Sort.asc);
    });
  }

  QueryBuilder<CollectionFolder, CollectionFolder, QAfterSortBy>
      sortByBinnedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'binnedAt', Sort.desc);
    });
  }

  QueryBuilder<CollectionFolder, CollectionFolder, QAfterSortBy>
      sortByBinnedFromFolderId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'binnedFromFolderId', Sort.asc);
    });
  }

  QueryBuilder<CollectionFolder, CollectionFolder, QAfterSortBy>
      sortByBinnedFromFolderIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'binnedFromFolderId', Sort.desc);
    });
  }

  QueryBuilder<CollectionFolder, CollectionFolder, QAfterSortBy>
      sortByFolderId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'folderId', Sort.asc);
    });
  }

  QueryBuilder<CollectionFolder, CollectionFolder, QAfterSortBy>
      sortByFolderIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'folderId', Sort.desc);
    });
  }

  QueryBuilder<CollectionFolder, CollectionFolder, QAfterSortBy> sortByName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'name', Sort.asc);
    });
  }

  QueryBuilder<CollectionFolder, CollectionFolder, QAfterSortBy>
      sortByNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'name', Sort.desc);
    });
  }

  QueryBuilder<CollectionFolder, CollectionFolder, QAfterSortBy> sortByOrder() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'order', Sort.asc);
    });
  }

  QueryBuilder<CollectionFolder, CollectionFolder, QAfterSortBy>
      sortByOrderDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'order', Sort.desc);
    });
  }

  QueryBuilder<CollectionFolder, CollectionFolder, QAfterSortBy>
      sortByParentId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'parentId', Sort.asc);
    });
  }

  QueryBuilder<CollectionFolder, CollectionFolder, QAfterSortBy>
      sortByParentIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'parentId', Sort.desc);
    });
  }
}

extension CollectionFolderQuerySortThenBy
    on QueryBuilder<CollectionFolder, CollectionFolder, QSortThenBy> {
  QueryBuilder<CollectionFolder, CollectionFolder, QAfterSortBy>
      thenByBinnedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'binnedAt', Sort.asc);
    });
  }

  QueryBuilder<CollectionFolder, CollectionFolder, QAfterSortBy>
      thenByBinnedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'binnedAt', Sort.desc);
    });
  }

  QueryBuilder<CollectionFolder, CollectionFolder, QAfterSortBy>
      thenByBinnedFromFolderId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'binnedFromFolderId', Sort.asc);
    });
  }

  QueryBuilder<CollectionFolder, CollectionFolder, QAfterSortBy>
      thenByBinnedFromFolderIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'binnedFromFolderId', Sort.desc);
    });
  }

  QueryBuilder<CollectionFolder, CollectionFolder, QAfterSortBy>
      thenByFolderId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'folderId', Sort.asc);
    });
  }

  QueryBuilder<CollectionFolder, CollectionFolder, QAfterSortBy>
      thenByFolderIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'folderId', Sort.desc);
    });
  }

  QueryBuilder<CollectionFolder, CollectionFolder, QAfterSortBy> thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<CollectionFolder, CollectionFolder, QAfterSortBy>
      thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<CollectionFolder, CollectionFolder, QAfterSortBy> thenByName() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'name', Sort.asc);
    });
  }

  QueryBuilder<CollectionFolder, CollectionFolder, QAfterSortBy>
      thenByNameDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'name', Sort.desc);
    });
  }

  QueryBuilder<CollectionFolder, CollectionFolder, QAfterSortBy> thenByOrder() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'order', Sort.asc);
    });
  }

  QueryBuilder<CollectionFolder, CollectionFolder, QAfterSortBy>
      thenByOrderDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'order', Sort.desc);
    });
  }

  QueryBuilder<CollectionFolder, CollectionFolder, QAfterSortBy>
      thenByParentId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'parentId', Sort.asc);
    });
  }

  QueryBuilder<CollectionFolder, CollectionFolder, QAfterSortBy>
      thenByParentIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'parentId', Sort.desc);
    });
  }
}

extension CollectionFolderQueryWhereDistinct
    on QueryBuilder<CollectionFolder, CollectionFolder, QDistinct> {
  QueryBuilder<CollectionFolder, CollectionFolder, QDistinct>
      distinctByBinnedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'binnedAt');
    });
  }

  QueryBuilder<CollectionFolder, CollectionFolder, QDistinct>
      distinctByBinnedFromFolderId({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'binnedFromFolderId',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<CollectionFolder, CollectionFolder, QDistinct>
      distinctByFolderId({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'folderId', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<CollectionFolder, CollectionFolder, QDistinct> distinctByName(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'name', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<CollectionFolder, CollectionFolder, QDistinct>
      distinctByOrder() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'order');
    });
  }

  QueryBuilder<CollectionFolder, CollectionFolder, QDistinct>
      distinctByParentId({bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'parentId', caseSensitive: caseSensitive);
    });
  }
}

extension CollectionFolderQueryProperty
    on QueryBuilder<CollectionFolder, CollectionFolder, QQueryProperty> {
  QueryBuilder<CollectionFolder, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<CollectionFolder, DateTime?, QQueryOperations>
      binnedAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'binnedAt');
    });
  }

  QueryBuilder<CollectionFolder, String?, QQueryOperations>
      binnedFromFolderIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'binnedFromFolderId');
    });
  }

  QueryBuilder<CollectionFolder, String, QQueryOperations> folderIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'folderId');
    });
  }

  QueryBuilder<CollectionFolder, String, QQueryOperations> nameProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'name');
    });
  }

  QueryBuilder<CollectionFolder, int, QQueryOperations> orderProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'order');
    });
  }

  QueryBuilder<CollectionFolder, String?, QQueryOperations> parentIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'parentId');
    });
  }
}
