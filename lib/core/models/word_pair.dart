import 'dart:convert';

import 'package:isar_community/isar.dart';

import 'translation_result.dart';

part 'word_pair.g.dart';

/// One row of the word list. Embedded inside [Session] — Isar has no separate
/// collection for it, so a row only ever exists as part of the session it was
/// collected in.
@embedded
class WordPair {
  String word;
  String translation;

  /// Drives the dots button next to the Translation field: solid once a
  /// translate brought a dictionary block back. See `docs/lightning_icon_rules.md`.
  bool hasTranslationOptions;

  /// The dots popup's body, stored as JSON rather than as an embedded object:
  /// this is Google's shape, and a string survives Google changing it.
  String? translationOptionsJson;

  bool wordMarkedFilled;
  bool translationMarkedFilled;

  WordPair({
    this.word = '',
    this.translation = '',
    this.hasTranslationOptions = false,
    this.translationOptionsJson,
    this.wordMarkedFilled = false,
    this.translationMarkedFilled = false,
  });

  @ignore
  TranslationResult? get translationOptions {
    if (translationOptionsJson == null) return null;
    try {
      final json = jsonDecode(translationOptionsJson!) as Map<String, dynamic>;
      return TranslationResult.fromJson(json);
    } catch (_) {
      return null;
    }
  }

  set translationOptions(TranslationResult? value) {
    if (value == null) {
      translationOptionsJson = null;
    } else {
      translationOptionsJson = jsonEncode(value.toJson());
    }
  }

  factory WordPair.fromJson(Map<String, dynamic> json) => WordPair(
        word: json['word'] as String? ?? '',
        translation: json['translation'] as String? ?? '',
        hasTranslationOptions: json['hasTranslationOptions'] as bool? ?? false,
        translationOptionsJson: json['translationOptionsJson'] as String?,
        wordMarkedFilled: json['wordMarkedFilled'] as bool? ?? false,
        translationMarkedFilled: json['translationMarkedFilled'] as bool? ?? false,
      );

  Map<String, dynamic> toJson() => {
        'word': word,
        'translation': translation,
        'hasTranslationOptions': hasTranslationOptions,
        'translationOptionsJson': translationOptionsJson,
        'wordMarkedFilled': wordMarkedFilled,
        'translationMarkedFilled': translationMarkedFilled,
      };

  /// A verbatim copy — used when writing to / reading from the store so the
  /// stored object and the one the screen holds never share a reference.
  WordPair copy() => WordPair(
        word: word,
        translation: translation,
        hasTranslationOptions: hasTranslationOptions,
        translationOptionsJson: translationOptionsJson,
        wordMarkedFilled: wordMarkedFilled,
        translationMarkedFilled: translationMarkedFilled,
      );

  @ignore
  bool get isEmpty => word.trim().isEmpty && translation.trim().isEmpty;
  @ignore
  bool get isValid => word.trim().isNotEmpty && translation.trim().isNotEmpty;
}
