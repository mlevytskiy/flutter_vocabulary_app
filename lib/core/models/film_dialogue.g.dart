// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'film_dialogue.dart';

// **************************************************************************
// IsarEmbeddedGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

const FilmDialogueSchema = Schema(
  name: r'FilmDialogue',
  id: -4882613743447078208,
  properties: {
    r'hidden': PropertySchema(
      id: 0,
      name: r'hidden',
      type: IsarType.bool,
    ),
    r'id': PropertySchema(
      id: 1,
      name: r'id',
      type: IsarType.string,
    ),
    r'importId': PropertySchema(
      id: 2,
      name: r'importId',
      type: IsarType.string,
    ),
    r'importRowIds': PropertySchema(
      id: 3,
      name: r'importRowIds',
      type: IsarType.stringList,
    ),
    r'lines': PropertySchema(
      id: 4,
      name: r'lines',
      type: IsarType.stringList,
    ),
    r'picturePushState': PropertySchema(
      id: 5,
      name: r'picturePushState',
      type: IsarType.byte,
      enumMap: _FilmDialoguepicturePushStateEnumValueMap,
    ),
    r'pushState': PropertySchema(
      id: 6,
      name: r'pushState',
      type: IsarType.byte,
      enumMap: _FilmDialoguepushStateEnumValueMap,
    ),
    r'scenePictureRunId': PropertySchema(
      id: 7,
      name: r'scenePictureRunId',
      type: IsarType.string,
    ),
    r'wordRowIds': PropertySchema(
      id: 8,
      name: r'wordRowIds',
      type: IsarType.stringList,
    )
  },
  estimateSize: _filmDialogueEstimateSize,
  serialize: _filmDialogueSerialize,
  deserialize: _filmDialogueDeserialize,
  deserializeProp: _filmDialogueDeserializeProp,
);

int _filmDialogueEstimateSize(
  FilmDialogue object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  bytesCount += 3 + object.id.length * 3;
  {
    final value = object.importId;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  bytesCount += 3 + object.importRowIds.length * 3;
  {
    for (var i = 0; i < object.importRowIds.length; i++) {
      final value = object.importRowIds[i];
      bytesCount += value.length * 3;
    }
  }
  bytesCount += 3 + object.lines.length * 3;
  {
    for (var i = 0; i < object.lines.length; i++) {
      final value = object.lines[i];
      bytesCount += value.length * 3;
    }
  }
  {
    final value = object.scenePictureRunId;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  bytesCount += 3 + object.wordRowIds.length * 3;
  {
    for (var i = 0; i < object.wordRowIds.length; i++) {
      final value = object.wordRowIds[i];
      bytesCount += value.length * 3;
    }
  }
  return bytesCount;
}

void _filmDialogueSerialize(
  FilmDialogue object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeBool(offsets[0], object.hidden);
  writer.writeString(offsets[1], object.id);
  writer.writeString(offsets[2], object.importId);
  writer.writeStringList(offsets[3], object.importRowIds);
  writer.writeStringList(offsets[4], object.lines);
  writer.writeByte(offsets[5], object.picturePushState.index);
  writer.writeByte(offsets[6], object.pushState.index);
  writer.writeString(offsets[7], object.scenePictureRunId);
  writer.writeStringList(offsets[8], object.wordRowIds);
}

FilmDialogue _filmDialogueDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = FilmDialogue();
  object.hidden = reader.readBool(offsets[0]);
  object.id = reader.readString(offsets[1]);
  object.importId = reader.readStringOrNull(offsets[2]);
  object.importRowIds = reader.readStringList(offsets[3]) ?? [];
  object.lines = reader.readStringList(offsets[4]) ?? [];
  object.picturePushState = _FilmDialoguepicturePushStateValueEnumMap[
          reader.readByteOrNull(offsets[5])] ??
      PushState.none;
  object.pushState =
      _FilmDialoguepushStateValueEnumMap[reader.readByteOrNull(offsets[6])] ??
          PushState.none;
  object.scenePictureRunId = reader.readStringOrNull(offsets[7]);
  object.wordRowIds = reader.readStringList(offsets[8]) ?? [];
  return object;
}

P _filmDialogueDeserializeProp<P>(
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
      return (reader.readStringOrNull(offset)) as P;
    case 3:
      return (reader.readStringList(offset) ?? []) as P;
    case 4:
      return (reader.readStringList(offset) ?? []) as P;
    case 5:
      return (_FilmDialoguepicturePushStateValueEnumMap[
              reader.readByteOrNull(offset)] ??
          PushState.none) as P;
    case 6:
      return (_FilmDialoguepushStateValueEnumMap[
              reader.readByteOrNull(offset)] ??
          PushState.none) as P;
    case 7:
      return (reader.readStringOrNull(offset)) as P;
    case 8:
      return (reader.readStringList(offset) ?? []) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

const _FilmDialoguepicturePushStateEnumValueMap = {
  'none': 0,
  'pending': 1,
  'delivered': 2,
};
const _FilmDialoguepicturePushStateValueEnumMap = {
  0: PushState.none,
  1: PushState.pending,
  2: PushState.delivered,
};
const _FilmDialoguepushStateEnumValueMap = {
  'none': 0,
  'pending': 1,
  'delivered': 2,
};
const _FilmDialoguepushStateValueEnumMap = {
  0: PushState.none,
  1: PushState.pending,
  2: PushState.delivered,
};

extension FilmDialogueQueryFilter
    on QueryBuilder<FilmDialogue, FilmDialogue, QFilterCondition> {
  QueryBuilder<FilmDialogue, FilmDialogue, QAfterFilterCondition> hiddenEqualTo(
      bool value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'hidden',
        value: value,
      ));
    });
  }

  QueryBuilder<FilmDialogue, FilmDialogue, QAfterFilterCondition> idEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'id',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<FilmDialogue, FilmDialogue, QAfterFilterCondition> idGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'id',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<FilmDialogue, FilmDialogue, QAfterFilterCondition> idLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'id',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<FilmDialogue, FilmDialogue, QAfterFilterCondition> idBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'id',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<FilmDialogue, FilmDialogue, QAfterFilterCondition> idStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'id',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<FilmDialogue, FilmDialogue, QAfterFilterCondition> idEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'id',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<FilmDialogue, FilmDialogue, QAfterFilterCondition> idContains(
      String value,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'id',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<FilmDialogue, FilmDialogue, QAfterFilterCondition> idMatches(
      String pattern,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'id',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<FilmDialogue, FilmDialogue, QAfterFilterCondition> idIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'id',
        value: '',
      ));
    });
  }

  QueryBuilder<FilmDialogue, FilmDialogue, QAfterFilterCondition>
      idIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'id',
        value: '',
      ));
    });
  }

  QueryBuilder<FilmDialogue, FilmDialogue, QAfterFilterCondition>
      importIdIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'importId',
      ));
    });
  }

  QueryBuilder<FilmDialogue, FilmDialogue, QAfterFilterCondition>
      importIdIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'importId',
      ));
    });
  }

  QueryBuilder<FilmDialogue, FilmDialogue, QAfterFilterCondition>
      importIdEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'importId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<FilmDialogue, FilmDialogue, QAfterFilterCondition>
      importIdGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'importId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<FilmDialogue, FilmDialogue, QAfterFilterCondition>
      importIdLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'importId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<FilmDialogue, FilmDialogue, QAfterFilterCondition>
      importIdBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'importId',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<FilmDialogue, FilmDialogue, QAfterFilterCondition>
      importIdStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'importId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<FilmDialogue, FilmDialogue, QAfterFilterCondition>
      importIdEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'importId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<FilmDialogue, FilmDialogue, QAfterFilterCondition>
      importIdContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'importId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<FilmDialogue, FilmDialogue, QAfterFilterCondition>
      importIdMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'importId',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<FilmDialogue, FilmDialogue, QAfterFilterCondition>
      importIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'importId',
        value: '',
      ));
    });
  }

  QueryBuilder<FilmDialogue, FilmDialogue, QAfterFilterCondition>
      importIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'importId',
        value: '',
      ));
    });
  }

  QueryBuilder<FilmDialogue, FilmDialogue, QAfterFilterCondition>
      importRowIdsElementEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'importRowIds',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<FilmDialogue, FilmDialogue, QAfterFilterCondition>
      importRowIdsElementGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'importRowIds',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<FilmDialogue, FilmDialogue, QAfterFilterCondition>
      importRowIdsElementLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'importRowIds',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<FilmDialogue, FilmDialogue, QAfterFilterCondition>
      importRowIdsElementBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'importRowIds',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<FilmDialogue, FilmDialogue, QAfterFilterCondition>
      importRowIdsElementStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'importRowIds',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<FilmDialogue, FilmDialogue, QAfterFilterCondition>
      importRowIdsElementEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'importRowIds',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<FilmDialogue, FilmDialogue, QAfterFilterCondition>
      importRowIdsElementContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'importRowIds',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<FilmDialogue, FilmDialogue, QAfterFilterCondition>
      importRowIdsElementMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'importRowIds',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<FilmDialogue, FilmDialogue, QAfterFilterCondition>
      importRowIdsElementIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'importRowIds',
        value: '',
      ));
    });
  }

  QueryBuilder<FilmDialogue, FilmDialogue, QAfterFilterCondition>
      importRowIdsElementIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'importRowIds',
        value: '',
      ));
    });
  }

  QueryBuilder<FilmDialogue, FilmDialogue, QAfterFilterCondition>
      importRowIdsLengthEqualTo(int length) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'importRowIds',
        length,
        true,
        length,
        true,
      );
    });
  }

  QueryBuilder<FilmDialogue, FilmDialogue, QAfterFilterCondition>
      importRowIdsIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'importRowIds',
        0,
        true,
        0,
        true,
      );
    });
  }

  QueryBuilder<FilmDialogue, FilmDialogue, QAfterFilterCondition>
      importRowIdsIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'importRowIds',
        0,
        false,
        999999,
        true,
      );
    });
  }

  QueryBuilder<FilmDialogue, FilmDialogue, QAfterFilterCondition>
      importRowIdsLengthLessThan(
    int length, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'importRowIds',
        0,
        true,
        length,
        include,
      );
    });
  }

  QueryBuilder<FilmDialogue, FilmDialogue, QAfterFilterCondition>
      importRowIdsLengthGreaterThan(
    int length, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'importRowIds',
        length,
        include,
        999999,
        true,
      );
    });
  }

  QueryBuilder<FilmDialogue, FilmDialogue, QAfterFilterCondition>
      importRowIdsLengthBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'importRowIds',
        lower,
        includeLower,
        upper,
        includeUpper,
      );
    });
  }

  QueryBuilder<FilmDialogue, FilmDialogue, QAfterFilterCondition>
      linesElementEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'lines',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<FilmDialogue, FilmDialogue, QAfterFilterCondition>
      linesElementGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'lines',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<FilmDialogue, FilmDialogue, QAfterFilterCondition>
      linesElementLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'lines',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<FilmDialogue, FilmDialogue, QAfterFilterCondition>
      linesElementBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'lines',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<FilmDialogue, FilmDialogue, QAfterFilterCondition>
      linesElementStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'lines',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<FilmDialogue, FilmDialogue, QAfterFilterCondition>
      linesElementEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'lines',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<FilmDialogue, FilmDialogue, QAfterFilterCondition>
      linesElementContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'lines',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<FilmDialogue, FilmDialogue, QAfterFilterCondition>
      linesElementMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'lines',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<FilmDialogue, FilmDialogue, QAfterFilterCondition>
      linesElementIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'lines',
        value: '',
      ));
    });
  }

  QueryBuilder<FilmDialogue, FilmDialogue, QAfterFilterCondition>
      linesElementIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'lines',
        value: '',
      ));
    });
  }

  QueryBuilder<FilmDialogue, FilmDialogue, QAfterFilterCondition>
      linesLengthEqualTo(int length) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'lines',
        length,
        true,
        length,
        true,
      );
    });
  }

  QueryBuilder<FilmDialogue, FilmDialogue, QAfterFilterCondition>
      linesIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'lines',
        0,
        true,
        0,
        true,
      );
    });
  }

  QueryBuilder<FilmDialogue, FilmDialogue, QAfterFilterCondition>
      linesIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'lines',
        0,
        false,
        999999,
        true,
      );
    });
  }

  QueryBuilder<FilmDialogue, FilmDialogue, QAfterFilterCondition>
      linesLengthLessThan(
    int length, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'lines',
        0,
        true,
        length,
        include,
      );
    });
  }

  QueryBuilder<FilmDialogue, FilmDialogue, QAfterFilterCondition>
      linesLengthGreaterThan(
    int length, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'lines',
        length,
        include,
        999999,
        true,
      );
    });
  }

  QueryBuilder<FilmDialogue, FilmDialogue, QAfterFilterCondition>
      linesLengthBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'lines',
        lower,
        includeLower,
        upper,
        includeUpper,
      );
    });
  }

  QueryBuilder<FilmDialogue, FilmDialogue, QAfterFilterCondition>
      picturePushStateEqualTo(PushState value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'picturePushState',
        value: value,
      ));
    });
  }

  QueryBuilder<FilmDialogue, FilmDialogue, QAfterFilterCondition>
      picturePushStateGreaterThan(
    PushState value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'picturePushState',
        value: value,
      ));
    });
  }

  QueryBuilder<FilmDialogue, FilmDialogue, QAfterFilterCondition>
      picturePushStateLessThan(
    PushState value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'picturePushState',
        value: value,
      ));
    });
  }

  QueryBuilder<FilmDialogue, FilmDialogue, QAfterFilterCondition>
      picturePushStateBetween(
    PushState lower,
    PushState upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'picturePushState',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<FilmDialogue, FilmDialogue, QAfterFilterCondition>
      pushStateEqualTo(PushState value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'pushState',
        value: value,
      ));
    });
  }

  QueryBuilder<FilmDialogue, FilmDialogue, QAfterFilterCondition>
      pushStateGreaterThan(
    PushState value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'pushState',
        value: value,
      ));
    });
  }

  QueryBuilder<FilmDialogue, FilmDialogue, QAfterFilterCondition>
      pushStateLessThan(
    PushState value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'pushState',
        value: value,
      ));
    });
  }

  QueryBuilder<FilmDialogue, FilmDialogue, QAfterFilterCondition>
      pushStateBetween(
    PushState lower,
    PushState upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'pushState',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<FilmDialogue, FilmDialogue, QAfterFilterCondition>
      scenePictureRunIdIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'scenePictureRunId',
      ));
    });
  }

  QueryBuilder<FilmDialogue, FilmDialogue, QAfterFilterCondition>
      scenePictureRunIdIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'scenePictureRunId',
      ));
    });
  }

  QueryBuilder<FilmDialogue, FilmDialogue, QAfterFilterCondition>
      scenePictureRunIdEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'scenePictureRunId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<FilmDialogue, FilmDialogue, QAfterFilterCondition>
      scenePictureRunIdGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'scenePictureRunId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<FilmDialogue, FilmDialogue, QAfterFilterCondition>
      scenePictureRunIdLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'scenePictureRunId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<FilmDialogue, FilmDialogue, QAfterFilterCondition>
      scenePictureRunIdBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'scenePictureRunId',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<FilmDialogue, FilmDialogue, QAfterFilterCondition>
      scenePictureRunIdStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'scenePictureRunId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<FilmDialogue, FilmDialogue, QAfterFilterCondition>
      scenePictureRunIdEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'scenePictureRunId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<FilmDialogue, FilmDialogue, QAfterFilterCondition>
      scenePictureRunIdContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'scenePictureRunId',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<FilmDialogue, FilmDialogue, QAfterFilterCondition>
      scenePictureRunIdMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'scenePictureRunId',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<FilmDialogue, FilmDialogue, QAfterFilterCondition>
      scenePictureRunIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'scenePictureRunId',
        value: '',
      ));
    });
  }

  QueryBuilder<FilmDialogue, FilmDialogue, QAfterFilterCondition>
      scenePictureRunIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'scenePictureRunId',
        value: '',
      ));
    });
  }

  QueryBuilder<FilmDialogue, FilmDialogue, QAfterFilterCondition>
      wordRowIdsElementEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'wordRowIds',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<FilmDialogue, FilmDialogue, QAfterFilterCondition>
      wordRowIdsElementGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'wordRowIds',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<FilmDialogue, FilmDialogue, QAfterFilterCondition>
      wordRowIdsElementLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'wordRowIds',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<FilmDialogue, FilmDialogue, QAfterFilterCondition>
      wordRowIdsElementBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'wordRowIds',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<FilmDialogue, FilmDialogue, QAfterFilterCondition>
      wordRowIdsElementStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'wordRowIds',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<FilmDialogue, FilmDialogue, QAfterFilterCondition>
      wordRowIdsElementEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'wordRowIds',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<FilmDialogue, FilmDialogue, QAfterFilterCondition>
      wordRowIdsElementContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'wordRowIds',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<FilmDialogue, FilmDialogue, QAfterFilterCondition>
      wordRowIdsElementMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'wordRowIds',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<FilmDialogue, FilmDialogue, QAfterFilterCondition>
      wordRowIdsElementIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'wordRowIds',
        value: '',
      ));
    });
  }

  QueryBuilder<FilmDialogue, FilmDialogue, QAfterFilterCondition>
      wordRowIdsElementIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'wordRowIds',
        value: '',
      ));
    });
  }

  QueryBuilder<FilmDialogue, FilmDialogue, QAfterFilterCondition>
      wordRowIdsLengthEqualTo(int length) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'wordRowIds',
        length,
        true,
        length,
        true,
      );
    });
  }

  QueryBuilder<FilmDialogue, FilmDialogue, QAfterFilterCondition>
      wordRowIdsIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'wordRowIds',
        0,
        true,
        0,
        true,
      );
    });
  }

  QueryBuilder<FilmDialogue, FilmDialogue, QAfterFilterCondition>
      wordRowIdsIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'wordRowIds',
        0,
        false,
        999999,
        true,
      );
    });
  }

  QueryBuilder<FilmDialogue, FilmDialogue, QAfterFilterCondition>
      wordRowIdsLengthLessThan(
    int length, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'wordRowIds',
        0,
        true,
        length,
        include,
      );
    });
  }

  QueryBuilder<FilmDialogue, FilmDialogue, QAfterFilterCondition>
      wordRowIdsLengthGreaterThan(
    int length, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'wordRowIds',
        length,
        include,
        999999,
        true,
      );
    });
  }

  QueryBuilder<FilmDialogue, FilmDialogue, QAfterFilterCondition>
      wordRowIdsLengthBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.listLength(
        r'wordRowIds',
        lower,
        includeLower,
        upper,
        includeUpper,
      );
    });
  }
}

extension FilmDialogueQueryObject
    on QueryBuilder<FilmDialogue, FilmDialogue, QFilterCondition> {}
