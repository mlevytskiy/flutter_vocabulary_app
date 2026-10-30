// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'word_origin.dart';

// **************************************************************************
// IsarEmbeddedGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types, experimental_member_use

const WordOriginSchema = Schema(
  name: r'WordOrigin',
  id: 6703895693585448295,
  properties: {
    r'episode': PropertySchema(
      id: 0,
      name: r'episode',
      type: IsarType.long,
    ),
    r'movieName': PropertySchema(
      id: 1,
      name: r'movieName',
      type: IsarType.string,
    ),
    r'season': PropertySchema(
      id: 2,
      name: r'season',
      type: IsarType.long,
    ),
    r'time': PropertySchema(
      id: 3,
      name: r'time',
      type: IsarType.string,
    ),
    r'typeOfSource': PropertySchema(
      id: 4,
      name: r'typeOfSource',
      type: IsarType.string,
      enumMap: _WordOrigintypeOfSourceEnumValueMap,
    ),
    r'wasDescriptionEditByUser': PropertySchema(
      id: 5,
      name: r'wasDescriptionEditByUser',
      type: IsarType.bool,
    ),
    r'wasTranslationEditByUser': PropertySchema(
      id: 6,
      name: r'wasTranslationEditByUser',
      type: IsarType.bool,
    )
  },
  estimateSize: _wordOriginEstimateSize,
  serialize: _wordOriginSerialize,
  deserialize: _wordOriginDeserialize,
  deserializeProp: _wordOriginDeserializeProp,
);

int _wordOriginEstimateSize(
  WordOrigin object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  bytesCount += 3 + object.movieName.length * 3;
  bytesCount += 3 + object.time.length * 3;
  bytesCount += 3 + object.typeOfSource.name.length * 3;
  return bytesCount;
}

void _wordOriginSerialize(
  WordOrigin object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeLong(offsets[0], object.episode);
  writer.writeString(offsets[1], object.movieName);
  writer.writeLong(offsets[2], object.season);
  writer.writeString(offsets[3], object.time);
  writer.writeString(offsets[4], object.typeOfSource.name);
  writer.writeBool(offsets[5], object.wasDescriptionEditByUser);
  writer.writeBool(offsets[6], object.wasTranslationEditByUser);
}

WordOrigin _wordOriginDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = WordOrigin();
  object.episode = reader.readLongOrNull(offsets[0]);
  object.movieName = reader.readString(offsets[1]);
  object.season = reader.readLongOrNull(offsets[2]);
  object.time = reader.readString(offsets[3]);
  object.typeOfSource = _WordOrigintypeOfSourceValueEnumMap[
          reader.readStringOrNull(offsets[4])] ??
      SourceType.manuallyEntered;
  object.wasDescriptionEditByUser = reader.readBool(offsets[5]);
  object.wasTranslationEditByUser = reader.readBool(offsets[6]);
  return object;
}

P _wordOriginDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readLongOrNull(offset)) as P;
    case 1:
      return (reader.readString(offset)) as P;
    case 2:
      return (reader.readLongOrNull(offset)) as P;
    case 3:
      return (reader.readString(offset)) as P;
    case 4:
      return (_WordOrigintypeOfSourceValueEnumMap[
              reader.readStringOrNull(offset)] ??
          SourceType.manuallyEntered) as P;
    case 5:
      return (reader.readBool(offset)) as P;
    case 6:
      return (reader.readBool(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

const _WordOrigintypeOfSourceEnumValueMap = {
  r'manuallyEntered': r'manuallyEntered',
  r'movie': r'movie',
  r'image': r'image',
  r'set': r'set',
};
const _WordOrigintypeOfSourceValueEnumMap = {
  r'manuallyEntered': SourceType.manuallyEntered,
  r'movie': SourceType.movie,
  r'image': SourceType.image,
  r'set': SourceType.set,
};

extension WordOriginQueryFilter
    on QueryBuilder<WordOrigin, WordOrigin, QFilterCondition> {
  QueryBuilder<WordOrigin, WordOrigin, QAfterFilterCondition> episodeIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'episode',
      ));
    });
  }

  QueryBuilder<WordOrigin, WordOrigin, QAfterFilterCondition>
      episodeIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'episode',
      ));
    });
  }

  QueryBuilder<WordOrigin, WordOrigin, QAfterFilterCondition> episodeEqualTo(
      int? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'episode',
        value: value,
      ));
    });
  }

  QueryBuilder<WordOrigin, WordOrigin, QAfterFilterCondition>
      episodeGreaterThan(
    int? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'episode',
        value: value,
      ));
    });
  }

  QueryBuilder<WordOrigin, WordOrigin, QAfterFilterCondition> episodeLessThan(
    int? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'episode',
        value: value,
      ));
    });
  }

  QueryBuilder<WordOrigin, WordOrigin, QAfterFilterCondition> episodeBetween(
    int? lower,
    int? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'episode',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<WordOrigin, WordOrigin, QAfterFilterCondition> movieNameEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'movieName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<WordOrigin, WordOrigin, QAfterFilterCondition>
      movieNameGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'movieName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<WordOrigin, WordOrigin, QAfterFilterCondition> movieNameLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'movieName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<WordOrigin, WordOrigin, QAfterFilterCondition> movieNameBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'movieName',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<WordOrigin, WordOrigin, QAfterFilterCondition>
      movieNameStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'movieName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<WordOrigin, WordOrigin, QAfterFilterCondition> movieNameEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'movieName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<WordOrigin, WordOrigin, QAfterFilterCondition> movieNameContains(
      String value,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'movieName',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<WordOrigin, WordOrigin, QAfterFilterCondition> movieNameMatches(
      String pattern,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'movieName',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<WordOrigin, WordOrigin, QAfterFilterCondition>
      movieNameIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'movieName',
        value: '',
      ));
    });
  }

  QueryBuilder<WordOrigin, WordOrigin, QAfterFilterCondition>
      movieNameIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'movieName',
        value: '',
      ));
    });
  }

  QueryBuilder<WordOrigin, WordOrigin, QAfterFilterCondition> seasonIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'season',
      ));
    });
  }

  QueryBuilder<WordOrigin, WordOrigin, QAfterFilterCondition>
      seasonIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'season',
      ));
    });
  }

  QueryBuilder<WordOrigin, WordOrigin, QAfterFilterCondition> seasonEqualTo(
      int? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'season',
        value: value,
      ));
    });
  }

  QueryBuilder<WordOrigin, WordOrigin, QAfterFilterCondition> seasonGreaterThan(
    int? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'season',
        value: value,
      ));
    });
  }

  QueryBuilder<WordOrigin, WordOrigin, QAfterFilterCondition> seasonLessThan(
    int? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'season',
        value: value,
      ));
    });
  }

  QueryBuilder<WordOrigin, WordOrigin, QAfterFilterCondition> seasonBetween(
    int? lower,
    int? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'season',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<WordOrigin, WordOrigin, QAfterFilterCondition> timeEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'time',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<WordOrigin, WordOrigin, QAfterFilterCondition> timeGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'time',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<WordOrigin, WordOrigin, QAfterFilterCondition> timeLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'time',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<WordOrigin, WordOrigin, QAfterFilterCondition> timeBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'time',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<WordOrigin, WordOrigin, QAfterFilterCondition> timeStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'time',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<WordOrigin, WordOrigin, QAfterFilterCondition> timeEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'time',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<WordOrigin, WordOrigin, QAfterFilterCondition> timeContains(
      String value,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'time',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<WordOrigin, WordOrigin, QAfterFilterCondition> timeMatches(
      String pattern,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'time',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<WordOrigin, WordOrigin, QAfterFilterCondition> timeIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'time',
        value: '',
      ));
    });
  }

  QueryBuilder<WordOrigin, WordOrigin, QAfterFilterCondition> timeIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'time',
        value: '',
      ));
    });
  }

  QueryBuilder<WordOrigin, WordOrigin, QAfterFilterCondition>
      typeOfSourceEqualTo(
    SourceType value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'typeOfSource',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<WordOrigin, WordOrigin, QAfterFilterCondition>
      typeOfSourceGreaterThan(
    SourceType value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'typeOfSource',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<WordOrigin, WordOrigin, QAfterFilterCondition>
      typeOfSourceLessThan(
    SourceType value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'typeOfSource',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<WordOrigin, WordOrigin, QAfterFilterCondition>
      typeOfSourceBetween(
    SourceType lower,
    SourceType upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'typeOfSource',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<WordOrigin, WordOrigin, QAfterFilterCondition>
      typeOfSourceStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'typeOfSource',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<WordOrigin, WordOrigin, QAfterFilterCondition>
      typeOfSourceEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'typeOfSource',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<WordOrigin, WordOrigin, QAfterFilterCondition>
      typeOfSourceContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'typeOfSource',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<WordOrigin, WordOrigin, QAfterFilterCondition>
      typeOfSourceMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'typeOfSource',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<WordOrigin, WordOrigin, QAfterFilterCondition>
      typeOfSourceIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'typeOfSource',
        value: '',
      ));
    });
  }

  QueryBuilder<WordOrigin, WordOrigin, QAfterFilterCondition>
      typeOfSourceIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'typeOfSource',
        value: '',
      ));
    });
  }

  QueryBuilder<WordOrigin, WordOrigin, QAfterFilterCondition>
      wasDescriptionEditByUserEqualTo(bool value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'wasDescriptionEditByUser',
        value: value,
      ));
    });
  }

  QueryBuilder<WordOrigin, WordOrigin, QAfterFilterCondition>
      wasTranslationEditByUserEqualTo(bool value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'wasTranslationEditByUser',
        value: value,
      ));
    });
  }
}

extension WordOriginQueryObject
    on QueryBuilder<WordOrigin, WordOrigin, QFilterCondition> {}
