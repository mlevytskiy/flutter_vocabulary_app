// The subtitle import's options (words-from-subtitles). Wire values match
// docs/features/words-from-subtitles/contracts/openapi.yaml; labels are what
// the import dialog and Settings show.

/// The learner's level on the European scale (CONTEXT "English level"). The
/// phone skips the commonest words the level already knows
/// (subtitle_ignored_words.dart: 1000 for A1 and A2, 2000 for B1, 4000 for
/// B2, 6000 for C1, 8000 for C2); the level is not sent to the Worker.
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

/// Who translates the words the phone picked: Google Translate on the phone
/// (free, no film dialogues), or an AI on the Worker — an Anthropic model or
/// one served by OpenCode Zen.
enum SubtitleTranslator {
  google('Google Translate'),
  ai('AI'),
  opencode('AI via OpenCode');

  const SubtitleTranslator(this.label);
  final String label;
}

/// The models the Worker offers for subtitle imports (ADR-0004), with the
/// price per million tokens for the results dialog's approximate cost: the
/// Anthropic ones from Anthropic's price list, the OpenCode ones from Zen's
/// (opencode.ai/docs/zen, 2026-10-14). Prices change: update them and
/// [pricesAsOf] together.
enum SubtitleModel {
  sonnet5('claude-sonnet-5', 'Sonnet 5', inputUsdPerMTok: 2, outputUsdPerMTok: 10),
  sonnet55('claude-sonnet-5-5', 'Sonnet 5.5', inputUsdPerMTok: 2, outputUsdPerMTok: 10),
  haiku45('claude-haiku-4-5-20251001', 'Haiku 4.5', inputUsdPerMTok: 1, outputUsdPerMTok: 5),
  opus55('claude-opus-5-5', 'Opus 5.5', inputUsdPerMTok: 4, outputUsdPerMTok: 20),
  glm53Flash('glm-5.3-flash', 'GLM 5.3 Flash', inputUsdPerMTok: 0.15, outputUsdPerMTok: 0.5, opencode: true),
  deepseekV41Flash('deepseek-v4.1-flash', 'DeepSeek V4.1 Flash', inputUsdPerMTok: 0.3, outputUsdPerMTok: 1.2, opencode: true),
  minimaxM3('minimax-m3', 'MiniMax M3', inputUsdPerMTok: 0.3, outputUsdPerMTok: 1.2, opencode: true),
  deepseekV4Pro('deepseek-v4-pro', 'DeepSeek V4 Pro', inputUsdPerMTok: 1.74, outputUsdPerMTok: 3.48, opencode: true),
  kimiK3('kimi-k3', 'Kimi K3', inputUsdPerMTok: 3, outputUsdPerMTok: 15, opencode: true);

  const SubtitleModel(
    this.id,
    this.label, {
    required this.inputUsdPerMTok,
    required this.outputUsdPerMTok,
    this.opencode = false,
  });

  /// The date of the Anthropic price list the Anthropic prices come from.
  static const pricesAsOf = '2026-09-25';

  /// The models one translator offers, and the one it starts with.
  static List<SubtitleModel> offeredBy(SubtitleTranslator translator) =>
      values.where((m) => m.opencode == (translator == SubtitleTranslator.opencode)).toList();

  final String id;
  final String label;

  /// Served by OpenCode Zen rather than Anthropic.
  final bool opencode;
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

/// The one set of import values (level, maximum) in Settings plus the "Update with each import"
/// switch, the translator and the model (data-model.md Device preferences). The file itself is
/// never stored.
class SubtitleImportPrefs {
  const SubtitleImportPrefs({
    required this.level,
    required this.maximum,
    required this.updateEachImport,
    required this.model,
    this.translator = SubtitleTranslator.google,
    this.opencodeModel = SubtitleModel.glm53Flash,
    this.boostCloseRepeats = true,
    this.removeNames = true,
  });

  static const minMaximum = 1;
  static const maxMaximum = 100;

  static const firstLaunch = SubtitleImportPrefs(
    level: EnglishLevel.b2,
    maximum: 20,
    updateEachImport: true,
    model: SubtitleModel.sonnet5,
  );

  final EnglishLevel level;
  final int maximum;
  final bool updateEachImport;
  final SubtitleModel model;
  final SubtitleTranslator translator;

  /// The OpenCode model, kept apart from [model] (the Anthropic one) so
  /// switching translators keeps each choice.
  final SubtitleModel opencodeModel;

  /// Rank a word used again within a couple of lines higher than one only
  /// scattered over the film ([SubtitleWordCounter.closeRepeatWeight]); off
  /// ranks by how often a word is used alone.
  final bool boostCloseRepeats;

  /// Skip words that look like names ([SubtitleWordCounter.looksLikeName]).
  final bool removeNames;

  /// The model the Worker is asked to use for the chosen translator.
  SubtitleModel get modelInUse => translator == SubtitleTranslator.opencode ? opencodeModel : model;

  static bool isValidMaximum(int value) => value >= minMaximum && value <= maxMaximum;

  SubtitleImportPrefs copyWith({
    EnglishLevel? level,
    int? maximum,
    bool? updateEachImport,
    SubtitleModel? model,
    SubtitleTranslator? translator,
    SubtitleModel? opencodeModel,
    bool? boostCloseRepeats,
    bool? removeNames,
  }) =>
      SubtitleImportPrefs(
        level: level ?? this.level,
        maximum: maximum ?? this.maximum,
        updateEachImport: updateEachImport ?? this.updateEachImport,
        model: model ?? this.model,
        translator: translator ?? this.translator,
        opencodeModel: opencodeModel ?? this.opencodeModel,
        boostCloseRepeats: boostCloseRepeats ?? this.boostCloseRepeats,
        removeNames: removeNames ?? this.removeNames,
      );

  @override
  bool operator ==(Object other) =>
      other is SubtitleImportPrefs &&
      other.level == level &&
      other.maximum == maximum &&
      other.updateEachImport == updateEachImport &&
      other.model == model &&
      other.translator == translator &&
      other.opencodeModel == opencodeModel &&
      other.boostCloseRepeats == boostCloseRepeats &&
      other.removeNames == removeNames;

  @override
  int get hashCode => Object.hash(level, maximum, updateEachImport, model, translator, opencodeModel, boostCloseRepeats, removeNames);
}
