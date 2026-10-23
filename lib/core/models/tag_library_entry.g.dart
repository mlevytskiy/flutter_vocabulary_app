// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'tag_library_entry.dart';

// **************************************************************************
// IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types, experimental_member_use

extension GetTagLibraryEntryCollection on Isar {
  IsarCollection<TagLibraryEntry> get tagLibraryEntrys => this.collection();
}

const TagLibraryEntrySchema = CollectionSchema(
  name: r'TagLibraryEntry',
  id: 2871517399150448844,
  properties: {
    r'forgotten': PropertySchema(
      id: 0,
      name: r'forgotten',
      type: IsarType.bool,
    ),
    r'key': PropertySchema(
      id: 1,
      name: r'key',
      type: IsarType.string,
    ),
    r'kind': PropertySchema(
      id: 2,
      name: r'kind',
      type: IsarType.byte,
      enumMap: _TagLibraryEntrykindEnumValueMap,
    ),
    r'lastUsedAt': PropertySchema(
      id: 3,
      name: r'lastUsedAt',
      type: IsarType.dateTime,
    ),
    r'text': PropertySchema(
      id: 4,
      name: r'text',
      type: IsarType.string,
    )
  },
  estimateSize: _tagLibraryEntryEstimateSize,
  serialize: _tagLibraryEntrySerialize,
  deserialize: _tagLibraryEntryDeserialize,
  deserializeProp: _tagLibraryEntryDeserializeProp,
  idName: r'id',
  indexes: {
    r'kind_key': IndexSchema(
      id: 7116354353052040858,
      name: r'kind_key',
      unique: true,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'kind',
          type: IndexType.value,
          caseSensitive: false,
        ),
        IndexPropertySchema(
          name: r'key',
          type: IndexType.hash,
          caseSensitive: true,
        )
      ],
    )
  },
  links: {},
  embeddedSchemas: {},
  getId: _tagLibraryEntryGetId,
  getLinks: _tagLibraryEntryGetLinks,
  attach: _tagLibraryEntryAttach,
  version: '3.4.1',
);

int _tagLibraryEntryEstimateSize(
  TagLibraryEntry object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  bytesCount += 3 + object.key.length * 3;
  bytesCount += 3 + object.text.length * 3;
  return bytesCount;
}

void _tagLibraryEntrySerialize(
  TagLibraryEntry object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeBool(offsets[0], object.forgotten);
  writer.writeString(offsets[1], object.key);
  writer.writeByte(offsets[2], object.kind.index);
  writer.writeDateTime(offsets[3], object.lastUsedAt);
  writer.writeString(offsets[4], object.text);
}

TagLibraryEntry _tagLibraryEntryDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = TagLibraryEntry();
  object.forgotten = reader.readBool(offsets[0]);
  object.id = id;
  object.key = reader.readString(offsets[1]);
  object.kind =
      _TagLibraryEntrykindValueEnumMap[reader.readByteOrNull(offsets[2])] ??
          TagKind.origin;
  object.lastUsedAt = reader.readDateTimeOrNull(offsets[3]);
  object.text = reader.readString(offsets[4]);
  return object;
}

P _tagLibraryEntryDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readBool(offset)) as P;
    case 1:
      return (reader.readString(offset)) as P;
    case 2:
      return (_TagLibraryEntrykindValueEnumMap[reader.readByteOrNull(offset)] ??
          TagKind.origin) as P;
    case 3:
      return (reader.readDateTimeOrNull(offset)) as P;
    case 4:
      return (reader.readString(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

const _TagLibraryEntrykindEnumValueMap = {
  'origin': 0,
  'topic': 1,
};
const _TagLibraryEntrykindValueEnumMap = {
  0: TagKind.origin,
  1: TagKind.topic,
};

Id _tagLibraryEntryGetId(TagLibraryEntry object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _tagLibraryEntryGetLinks(TagLibraryEntry object) {
  return [];
}

void _tagLibraryEntryAttach(
    IsarCollection<dynamic> col, Id id, TagLibraryEntry object) {
  object.id = id;
}

extension TagLibraryEntryByIndex on IsarCollection<TagLibraryEntry> {
  Future<TagLibraryEntry?> getByKindKey(TagKind kind, String key) {
    return getByIndex(r'kind_key', [kind, key]);
  }

  TagLibraryEntry? getByKindKeySync(TagKind kind, String key) {
    return getByIndexSync(r'kind_key', [kind, key]);
  }

  Future<bool> deleteByKindKey(TagKind kind, String key) {
    return deleteByIndex(r'kind_key', [kind, key]);
  }

  bool deleteByKindKeySync(TagKind kind, String key) {
    return deleteByIndexSync(r'kind_key', [kind, key]);
  }

  Future<List<TagLibraryEntry?>> getAllByKindKey(
      List<TagKind> kindValues, List<String> keyValues) {
    final len = kindValues.length;
    assert(
        keyValues.length == len, 'All index values must have the same length');
    final values = <List<dynamic>>[];
    for (var i = 0; i < len; i++) {
      values.add([kindValues[i], keyValues[i]]);
    }

    return getAllByIndex(r'kind_key', values);
  }

  List<TagLibraryEntry?> getAllByKindKeySync(
      List<TagKind> kindValues, List<String> keyValues) {
    final len = kindValues.length;
    assert(
        keyValues.length == len, 'All index values must have the same length');
    final values = <List<dynamic>>[];
    for (var i = 0; i < len; i++) {
      values.add([kindValues[i], keyValues[i]]);
    }

    return getAllByIndexSync(r'kind_key', values);
  }

  Future<int> deleteAllByKindKey(
      List<TagKind> kindValues, List<String> keyValues) {
    final len = kindValues.length;
    assert(
        keyValues.length == len, 'All index values must have the same length');
    final values = <List<dynamic>>[];
    for (var i = 0; i < len; i++) {
      values.add([kindValues[i], keyValues[i]]);
    }

    return deleteAllByIndex(r'kind_key', values);
  }

  int deleteAllByKindKeySync(List<TagKind> kindValues, List<String> keyValues) {
    final len = kindValues.length;
    assert(
        keyValues.length == len, 'All index values must have the same length');
    final values = <List<dynamic>>[];
    for (var i = 0; i < len; i++) {
      values.add([kindValues[i], keyValues[i]]);
    }

    return deleteAllByIndexSync(r'kind_key', values);
  }

  Future<Id> putByKindKey(TagLibraryEntry object) {
    return putByIndex(r'kind_key', object);
  }

  Id putByKindKeySync(TagLibraryEntry object, {bool saveLinks = true}) {
    return putByIndexSync(r'kind_key', object, saveLinks: saveLinks);
  }

  Future<List<Id>> putAllByKindKey(List<TagLibraryEntry> objects) {
    return putAllByIndex(r'kind_key', objects);
  }

  List<Id> putAllByKindKeySync(List<TagLibraryEntry> objects,
      {bool saveLinks = true}) {
    return putAllByIndexSync(r'kind_key', objects, saveLinks: saveLinks);
  }
}

extension TagLibraryEntryQueryWhereSort
    on QueryBuilder<TagLibraryEntry, TagLibraryEntry, QWhere> {
  QueryBuilder<TagLibraryEntry, TagLibraryEntry, QAfterWhere> anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }
}

extension TagLibraryEntryQueryWhere
    on QueryBuilder<TagLibraryEntry, TagLibraryEntry, QWhereClause> {
  QueryBuilder<TagLibraryEntry, TagLibraryEntry, QAfterWhereClause> idEqualTo(
      Id id) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(
        lower: id,
        upper: id,
      ));
    });
  }

  QueryBuilder<TagLibraryEntry, TagLibraryEntry, QAfterWhereClause>
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

  QueryBuilder<TagLibraryEntry, TagLibraryEntry, QAfterWhereClause>
      idGreaterThan(Id id, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<TagLibraryEntry, TagLibraryEntry, QAfterWhereClause> idLessThan(
      Id id,
      {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<TagLibraryEntry, TagLibraryEntry, QAfterWhereClause> idBetween(
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

  QueryBuilder<TagLibraryEntry, TagLibraryEntry, QAfterWhereClause>
      kindEqualToAnyKey(TagKind kind) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'kind_key',
        value: [kind],
      ));
    });
  }

  QueryBuilder<TagLibraryEntry, TagLibraryEntry, QAfterWhereClause>
      kindNotEqualToAnyKey(TagKind kind) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'kind_key',
              lower: [],
              upper: [kind],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'kind_key',
              lower: [kind],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'kind_key',
              lower: [kind],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'kind_key',
              lower: [],
              upper: [kind],
              includeUpper: false,
            ));
      }
    });
  }

  QueryBuilder<TagLibraryEntry, TagLibraryEntry, QAfterWhereClause>
      kindGreaterThanAnyKey(
    TagKind kind, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'kind_key',
        lower: [kind],
        includeLower: include,
        upper: [],
      ));
    });
  }

  QueryBuilder<TagLibraryEntry, TagLibraryEntry, QAfterWhereClause>
      kindLessThanAnyKey(
    TagKind kind, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'kind_key',
        lower: [],
        upper: [kind],
        includeUpper: include,
      ));
    });
  }

  QueryBuilder<TagLibraryEntry, TagLibraryEntry, QAfterWhereClause>
      kindBetweenAnyKey(
    TagKind lowerKind,
    TagKind upperKind, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'kind_key',
        lower: [lowerKind],
        includeLower: includeLower,
        upper: [upperKind],
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<TagLibraryEntry, TagLibraryEntry, QAfterWhereClause>
      kindKeyEqualTo(TagKind kind, String key) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'kind_key',
        value: [kind, key],
      ));
    });
  }

  QueryBuilder<TagLibraryEntry, TagLibraryEntry, QAfterWhereClause>
      kindEqualToKeyNotEqualTo(TagKind kind, String key) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'kind_key',
              lower: [kind],
              upper: [kind, key],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'kind_key',
              lower: [kind, key],
              includeLower: false,
              upper: [kind],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'kind_key',
              lower: [kind, key],
              includeLower: false,
              upper: [kind],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'kind_key',
              lower: [kind],
              upper: [kind, key],
              includeUpper: false,
            ));
      }
    });
  }
}

extension TagLibraryEntryQueryFilter
    on QueryBuilder<TagLibraryEntry, TagLibraryEntry, QFilterCondition> {
  QueryBuilder<TagLibraryEntry, TagLibraryEntry, QAfterFilterCondition>
      forgottenEqualTo(bool value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'forgotten',
        value: value,
      ));
    });
  }

  QueryBuilder<TagLibraryEntry, TagLibraryEntry, QAfterFilterCondition>
      idEqualTo(Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<TagLibraryEntry, TagLibraryEntry, QAfterFilterCondition>
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

  QueryBuilder<TagLibraryEntry, TagLibraryEntry, QAfterFilterCondition>
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

  QueryBuilder<TagLibraryEntry, TagLibraryEntry, QAfterFilterCondition>
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

  QueryBuilder<TagLibraryEntry, TagLibraryEntry, QAfterFilterCondition>
      keyEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'key',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TagLibraryEntry, TagLibraryEntry, QAfterFilterCondition>
      keyGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'key',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TagLibraryEntry, TagLibraryEntry, QAfterFilterCondition>
      keyLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'key',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TagLibraryEntry, TagLibraryEntry, QAfterFilterCondition>
      keyBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'key',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TagLibraryEntry, TagLibraryEntry, QAfterFilterCondition>
      keyStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'key',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TagLibraryEntry, TagLibraryEntry, QAfterFilterCondition>
      keyEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'key',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TagLibraryEntry, TagLibraryEntry, QAfterFilterCondition>
      keyContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'key',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TagLibraryEntry, TagLibraryEntry, QAfterFilterCondition>
      keyMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'key',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TagLibraryEntry, TagLibraryEntry, QAfterFilterCondition>
      keyIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'key',
        value: '',
      ));
    });
  }

  QueryBuilder<TagLibraryEntry, TagLibraryEntry, QAfterFilterCondition>
      keyIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'key',
        value: '',
      ));
    });
  }

  QueryBuilder<TagLibraryEntry, TagLibraryEntry, QAfterFilterCondition>
      kindEqualTo(TagKind value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'kind',
        value: value,
      ));
    });
  }

  QueryBuilder<TagLibraryEntry, TagLibraryEntry, QAfterFilterCondition>
      kindGreaterThan(
    TagKind value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'kind',
        value: value,
      ));
    });
  }

  QueryBuilder<TagLibraryEntry, TagLibraryEntry, QAfterFilterCondition>
      kindLessThan(
    TagKind value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'kind',
        value: value,
      ));
    });
  }

  QueryBuilder<TagLibraryEntry, TagLibraryEntry, QAfterFilterCondition>
      kindBetween(
    TagKind lower,
    TagKind upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'kind',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<TagLibraryEntry, TagLibraryEntry, QAfterFilterCondition>
      lastUsedAtIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'lastUsedAt',
      ));
    });
  }

  QueryBuilder<TagLibraryEntry, TagLibraryEntry, QAfterFilterCondition>
      lastUsedAtIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'lastUsedAt',
      ));
    });
  }

  QueryBuilder<TagLibraryEntry, TagLibraryEntry, QAfterFilterCondition>
      lastUsedAtEqualTo(DateTime? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'lastUsedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<TagLibraryEntry, TagLibraryEntry, QAfterFilterCondition>
      lastUsedAtGreaterThan(
    DateTime? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'lastUsedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<TagLibraryEntry, TagLibraryEntry, QAfterFilterCondition>
      lastUsedAtLessThan(
    DateTime? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'lastUsedAt',
        value: value,
      ));
    });
  }

  QueryBuilder<TagLibraryEntry, TagLibraryEntry, QAfterFilterCondition>
      lastUsedAtBetween(
    DateTime? lower,
    DateTime? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'lastUsedAt',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<TagLibraryEntry, TagLibraryEntry, QAfterFilterCondition>
      textEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'text',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TagLibraryEntry, TagLibraryEntry, QAfterFilterCondition>
      textGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'text',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TagLibraryEntry, TagLibraryEntry, QAfterFilterCondition>
      textLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'text',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TagLibraryEntry, TagLibraryEntry, QAfterFilterCondition>
      textBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'text',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TagLibraryEntry, TagLibraryEntry, QAfterFilterCondition>
      textStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'text',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TagLibraryEntry, TagLibraryEntry, QAfterFilterCondition>
      textEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'text',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TagLibraryEntry, TagLibraryEntry, QAfterFilterCondition>
      textContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'text',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TagLibraryEntry, TagLibraryEntry, QAfterFilterCondition>
      textMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'text',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<TagLibraryEntry, TagLibraryEntry, QAfterFilterCondition>
      textIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'text',
        value: '',
      ));
    });
  }

  QueryBuilder<TagLibraryEntry, TagLibraryEntry, QAfterFilterCondition>
      textIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'text',
        value: '',
      ));
    });
  }
}

extension TagLibraryEntryQueryObject
    on QueryBuilder<TagLibraryEntry, TagLibraryEntry, QFilterCondition> {}

extension TagLibraryEntryQueryLinks
    on QueryBuilder<TagLibraryEntry, TagLibraryEntry, QFilterCondition> {}

extension TagLibraryEntryQuerySortBy
    on QueryBuilder<TagLibraryEntry, TagLibraryEntry, QSortBy> {
  QueryBuilder<TagLibraryEntry, TagLibraryEntry, QAfterSortBy>
      sortByForgotten() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'forgotten', Sort.asc);
    });
  }

  QueryBuilder<TagLibraryEntry, TagLibraryEntry, QAfterSortBy>
      sortByForgottenDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'forgotten', Sort.desc);
    });
  }

  QueryBuilder<TagLibraryEntry, TagLibraryEntry, QAfterSortBy> sortByKey() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'key', Sort.asc);
    });
  }

  QueryBuilder<TagLibraryEntry, TagLibraryEntry, QAfterSortBy> sortByKeyDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'key', Sort.desc);
    });
  }

  QueryBuilder<TagLibraryEntry, TagLibraryEntry, QAfterSortBy> sortByKind() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'kind', Sort.asc);
    });
  }

  QueryBuilder<TagLibraryEntry, TagLibraryEntry, QAfterSortBy>
      sortByKindDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'kind', Sort.desc);
    });
  }

  QueryBuilder<TagLibraryEntry, TagLibraryEntry, QAfterSortBy>
      sortByLastUsedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastUsedAt', Sort.asc);
    });
  }

  QueryBuilder<TagLibraryEntry, TagLibraryEntry, QAfterSortBy>
      sortByLastUsedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastUsedAt', Sort.desc);
    });
  }

  QueryBuilder<TagLibraryEntry, TagLibraryEntry, QAfterSortBy> sortByText() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'text', Sort.asc);
    });
  }

  QueryBuilder<TagLibraryEntry, TagLibraryEntry, QAfterSortBy>
      sortByTextDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'text', Sort.desc);
    });
  }
}

extension TagLibraryEntryQuerySortThenBy
    on QueryBuilder<TagLibraryEntry, TagLibraryEntry, QSortThenBy> {
  QueryBuilder<TagLibraryEntry, TagLibraryEntry, QAfterSortBy>
      thenByForgotten() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'forgotten', Sort.asc);
    });
  }

  QueryBuilder<TagLibraryEntry, TagLibraryEntry, QAfterSortBy>
      thenByForgottenDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'forgotten', Sort.desc);
    });
  }

  QueryBuilder<TagLibraryEntry, TagLibraryEntry, QAfterSortBy> thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<TagLibraryEntry, TagLibraryEntry, QAfterSortBy> thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<TagLibraryEntry, TagLibraryEntry, QAfterSortBy> thenByKey() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'key', Sort.asc);
    });
  }

  QueryBuilder<TagLibraryEntry, TagLibraryEntry, QAfterSortBy> thenByKeyDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'key', Sort.desc);
    });
  }

  QueryBuilder<TagLibraryEntry, TagLibraryEntry, QAfterSortBy> thenByKind() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'kind', Sort.asc);
    });
  }

  QueryBuilder<TagLibraryEntry, TagLibraryEntry, QAfterSortBy>
      thenByKindDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'kind', Sort.desc);
    });
  }

  QueryBuilder<TagLibraryEntry, TagLibraryEntry, QAfterSortBy>
      thenByLastUsedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastUsedAt', Sort.asc);
    });
  }

  QueryBuilder<TagLibraryEntry, TagLibraryEntry, QAfterSortBy>
      thenByLastUsedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastUsedAt', Sort.desc);
    });
  }

  QueryBuilder<TagLibraryEntry, TagLibraryEntry, QAfterSortBy> thenByText() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'text', Sort.asc);
    });
  }

  QueryBuilder<TagLibraryEntry, TagLibraryEntry, QAfterSortBy>
      thenByTextDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'text', Sort.desc);
    });
  }
}

extension TagLibraryEntryQueryWhereDistinct
    on QueryBuilder<TagLibraryEntry, TagLibraryEntry, QDistinct> {
  QueryBuilder<TagLibraryEntry, TagLibraryEntry, QDistinct>
      distinctByForgotten() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'forgotten');
    });
  }

  QueryBuilder<TagLibraryEntry, TagLibraryEntry, QDistinct> distinctByKey(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'key', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<TagLibraryEntry, TagLibraryEntry, QDistinct> distinctByKind() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'kind');
    });
  }

  QueryBuilder<TagLibraryEntry, TagLibraryEntry, QDistinct>
      distinctByLastUsedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'lastUsedAt');
    });
  }

  QueryBuilder<TagLibraryEntry, TagLibraryEntry, QDistinct> distinctByText(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'text', caseSensitive: caseSensitive);
    });
  }
}

extension TagLibraryEntryQueryProperty
    on QueryBuilder<TagLibraryEntry, TagLibraryEntry, QQueryProperty> {
  QueryBuilder<TagLibraryEntry, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<TagLibraryEntry, bool, QQueryOperations> forgottenProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'forgotten');
    });
  }

  QueryBuilder<TagLibraryEntry, String, QQueryOperations> keyProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'key');
    });
  }

  QueryBuilder<TagLibraryEntry, TagKind, QQueryOperations> kindProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'kind');
    });
  }

  QueryBuilder<TagLibraryEntry, DateTime?, QQueryOperations>
      lastUsedAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'lastUsedAt');
    });
  }

  QueryBuilder<TagLibraryEntry, String, QQueryOperations> textProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'text');
    });
  }
}
