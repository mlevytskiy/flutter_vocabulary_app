// The subtitle import's options (words-from-subtitles). Wire values match
// docs/features/words-from-subtitles/contracts/openapi.yaml; labels are what
// the import dialog and Settings show.

/// What the picked words are for (CONTEXT "import purpose").
enum ImportPurpose {
  understandFilm('understand_film', 'Understand this film'),
  frequentWords('frequent_words', 'Frequent words for the future');

  const ImportPurpose(this.wire, this.label);
  final String wire;
  final String label;
}

/// The learner's level on the European scale; words at or below it are not
/// proposed (CONTEXT "English level").
enum EnglishLevel {
  a1,
  a2,
  b1,
  b2,
  c1,
  c2;

  String get wire => name.toUpperCase();
  String get label => wire;
}

/// The models the Worker offers for subtitle imports (ADR-0004), with the
/// Anthropic price per million tokens for the results dialog's approximate
/// cost. Prices change: update them and [pricesAsOf] together.
enum SubtitleModel {
  sonnet5('claude-sonnet-5', 'Sonnet 5', inputUsdPerMTok: 2, outputUsdPerMTok: 10),
  sonnet55('claude-sonnet-5-5', 'Sonnet 5.5', inputUsdPerMTok: 2, outputUsdPerMTok: 10),
  haiku45('claude-haiku-4-5-20251001', 'Haiku 4.5', inputUsdPerMTok: 1, outputUsdPerMTok: 5),
  opus55('claude-opus-5-5', 'Opus 5.5', inputUsdPerMTok: 4, outputUsdPerMTok: 20);

  const SubtitleModel(this.id, this.label, {required this.inputUsdPerMTok, required this.outputUsdPerMTok});

  /// The date of the Anthropic price list the prices above come from.
  static const pricesAsOf = '2026-09-25';

  final String id;
  final String label;
  final double inputUsdPerMTok;
  final double outputUsdPerMTok;

  static SubtitleModel? byId(String id) {
    for (final model in values) {
      if (model.id == id) return model;
    }
    return null;
  }

  /// Approximate cost in US dollars of one import's AI call.
  double costUsd({required int inputTokens, required int outputTokens}) =>
      (inputTokens * inputUsdPerMTok + outputTokens * outputUsdPerMTok) / 1000000;
}

/// The one set of import values in Settings plus the "Update with each import"
/// switch and the model (data-model.md Device preferences). The file itself is
/// never stored.
class SubtitleImportPrefs {
  const SubtitleImportPrefs({
    required this.purpose,
    required this.level,
    required this.maximum,
    required this.updateEachImport,
    required this.model,
  });

  static const minMaximum = 1;
  static const maxMaximum = 100;

  static const firstLaunch = SubtitleImportPrefs(
    purpose: ImportPurpose.understandFilm,
    level: EnglishLevel.b2,
    maximum: 20,
    updateEachImport: true,
    model: SubtitleModel.sonnet5,
  );

  final ImportPurpose purpose;
  final EnglishLevel level;
  final int maximum;
  final bool updateEachImport;
  final SubtitleModel model;

  static bool isValidMaximum(int value) => value >= minMaximum && value <= maxMaximum;

  SubtitleImportPrefs copyWith({
    ImportPurpose? purpose,
    EnglishLevel? level,
    int? maximum,
    bool? updateEachImport,
    SubtitleModel? model,
  }) =>
      SubtitleImportPrefs(
        purpose: purpose ?? this.purpose,
        level: level ?? this.level,
        maximum: maximum ?? this.maximum,
        updateEachImport: updateEachImport ?? this.updateEachImport,
        model: model ?? this.model,
      );

  @override
  bool operator ==(Object other) =>
      other is SubtitleImportPrefs &&
      other.purpose == purpose &&
      other.level == level &&
      other.maximum == maximum &&
      other.updateEachImport == updateEachImport &&
      other.model == model;

  @override
  int get hashCode => Object.hash(purpose, level, maximum, updateEachImport, model);
}
