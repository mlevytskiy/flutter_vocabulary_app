// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'word_pair.dart';

// **************************************************************************
// IsarEmbeddedGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

const WordPairSchema = Schema(
  name: r'WordPair',
  id: -8222807404021742096,
  properties: {
    r'hasTranslationOptions': PropertySchema(
      id: 0,
      name: r'hasTranslationOptions',
      type: IsarType.bool,
    ),
    r'translation': PropertySchema(
      id: 1,
      name: r'translation',
      type: IsarType.string,
    ),
    r'translationMarkedFilled': PropertySchema(
      id: 2,
      name: r'translationMarkedFilled',
      type: IsarType.bool,
    ),
    r'translationOptionsJson': PropertySchema(
      id: 3,
      name: r'translationOptionsJson',
      type: IsarType.string,
    ),
    r'word': PropertySchema(
      id: 4,
      name: r'word',
      type: IsarType.string,
    ),
    r'wordMarkedFilled': PropertySchema(
      id: 5,
      name: r'wordMarkedFilled',
      type: IsarType.bool,
    )
  },
  estimateSize: _wordPairEstimateSize,
  serialize: _wordPairSerialize,
  deserialize: _wordPairDeserialize,
  deserializeProp: _wordPairDeserializeProp,
);

int _wordPairEstimateSize(
  WordPair object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  bytesCount += 3 + object.translation.length * 3;
  {
    final value = object.translationOptionsJson;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  bytesCount += 3 + object.word.length * 3;
  return bytesCount;
}

void _wordPairSerialize(
  WordPair object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeBool(offsets[0], object.hasTranslationOptions);
  writer.writeString(offsets[1], object.translation);
  writer.writeBool(offsets[2], object.translationMarkedFilled);
  writer.writeString(offsets[3], object.translationOptionsJson);
  writer.writeString(offsets[4], object.word);
  writer.writeBool(offsets[5], object.wordMarkedFilled);
}

WordPair _wordPairDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = WordPair(
    hasTranslationOptions: reader.readBoolOrNull(offsets[0]) ?? false,
    translation: reader.readStringOrNull(offsets[1]) ?? '',
    translationMarkedFilled: reader.readBoolOrNull(offsets[2]) ?? false,
    translationOptionsJson: reader.readStringOrNull(offsets[3]),
    word: reader.readStringOrNull(offsets[4]) ?? '',
    wordMarkedFilled: reader.readBoolOrNull(offsets[5]) ?? false,
  );
  return object;
}

P _wordPairDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readBoolOrNull(offset) ?? false) as P;
    case 1:
      return (reader.readStringOrNull(offset) ?? '') as P;
    case 2:
      return (reader.readBoolOrNull(offset) ?? false) as P;
    case 3:
      return (reader.readStringOrNull(offset)) as P;
    case 4:
      return (reader.readStringOrNull(offset) ?? '') as P;
    case 5:
      return (reader.readBoolOrNull(offset) ?? false) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

extension WordPairQueryFilter
    on QueryBuilder<WordPair, WordPair, QFilterCondition> {
  QueryBuilder<WordPair, WordPair, QAfterFilterCondition>
      hasTranslationOptionsEqualTo(bool value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'hasTranslationOptions',
        value: value,
      ));
    });
  }

  QueryBuilder<WordPair, WordPair, QAfterFilterCondition> translationEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'translation',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<WordPair, WordPair, QAfterFilterCondition>
      translationGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'translation',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<WordPair, WordPair, QAfterFilterCondition> translationLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'translation',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<WordPair, WordPair, QAfterFilterCondition> translationBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'translation',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<WordPair, WordPair, QAfterFilterCondition> translationStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'translation',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<WordPair, WordPair, QAfterFilterCondition> translationEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'translation',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<WordPair, WordPair, QAfterFilterCondition> translationContains(
      String value,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'translation',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<WordPair, WordPair, QAfterFilterCondition> translationMatches(
      String pattern,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'translation',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<WordPair, WordPair, QAfterFilterCondition> translationIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'translation',
        value: '',
      ));
    });
  }

  QueryBuilder<WordPair, WordPair, QAfterFilterCondition>
      translationIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'translation',
        value: '',
      ));
    });
  }

  QueryBuilder<WordPair, WordPair, QAfterFilterCondition>
      translationMarkedFilledEqualTo(bool value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'translationMarkedFilled',
        value: value,
      ));
    });
  }

  QueryBuilder<WordPair, WordPair, QAfterFilterCondition>
      translationOptionsJsonIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'translationOptionsJson',
      ));
    });
  }

  QueryBuilder<WordPair, WordPair, QAfterFilterCondition>
      translationOptionsJsonIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'translationOptionsJson',
      ));
    });
  }

  QueryBuilder<WordPair, WordPair, QAfterFilterCondition>
      translationOptionsJsonEqualTo(
    String? value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'translationOptionsJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<WordPair, WordPair, QAfterFilterCondition>
      translationOptionsJsonGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'translationOptionsJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<WordPair, WordPair, QAfterFilterCondition>
      translationOptionsJsonLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'translationOptionsJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<WordPair, WordPair, QAfterFilterCondition>
      translationOptionsJsonBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'translationOptionsJson',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<WordPair, WordPair, QAfterFilterCondition>
      translationOptionsJsonStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'translationOptionsJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<WordPair, WordPair, QAfterFilterCondition>
      translationOptionsJsonEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'translationOptionsJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<WordPair, WordPair, QAfterFilterCondition>
      translationOptionsJsonContains(String value,
          {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'translationOptionsJson',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<WordPair, WordPair, QAfterFilterCondition>
      translationOptionsJsonMatches(String pattern,
          {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'translationOptionsJson',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<WordPair, WordPair, QAfterFilterCondition>
      translationOptionsJsonIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'translationOptionsJson',
        value: '',
      ));
    });
  }

  QueryBuilder<WordPair, WordPair, QAfterFilterCondition>
      translationOptionsJsonIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'translationOptionsJson',
        value: '',
      ));
    });
  }

  QueryBuilder<WordPair, WordPair, QAfterFilterCondition> wordEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'word',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<WordPair, WordPair, QAfterFilterCondition> wordGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'word',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<WordPair, WordPair, QAfterFilterCondition> wordLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'word',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<WordPair, WordPair, QAfterFilterCondition> wordBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'word',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<WordPair, WordPair, QAfterFilterCondition> wordStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'word',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<WordPair, WordPair, QAfterFilterCondition> wordEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'word',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<WordPair, WordPair, QAfterFilterCondition> wordContains(
      String value,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'word',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<WordPair, WordPair, QAfterFilterCondition> wordMatches(
      String pattern,
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'word',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<WordPair, WordPair, QAfterFilterCondition> wordIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'word',
        value: '',
      ));
    });
  }

  QueryBuilder<WordPair, WordPair, QAfterFilterCondition> wordIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'word',
        value: '',
      ));
    });
  }

  QueryBuilder<WordPair, WordPair, QAfterFilterCondition>
      wordMarkedFilledEqualTo(bool value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'wordMarkedFilled',
        value: value,
      ));
    });
  }
}

extension WordPairQueryObject
    on QueryBuilder<WordPair, WordPair, QFilterCondition> {}
