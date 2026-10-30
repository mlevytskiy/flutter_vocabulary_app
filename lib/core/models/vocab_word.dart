class VocabWord {
  final String word;
  final String? context;
  final String? translation;
  final String? description;

  /// Where [context] came from (word-context AC-10): 'photo' for a line read
  /// on the photo, 'ai' for a sentence the AI wrote; null with no context.
  /// An older Worker sends no kind: a non-empty context then counts as
  /// 'photo'.
  final String? contextSource;

  VocabWord({
    required this.word,
    this.context,
    this.translation,
    this.description,
    this.contextSource,
  });

  factory VocabWord.fromJson(Map<String, dynamic> json) {
    final context = json['context'] as String?;
    final hasContext = (context ?? '').trim().isNotEmpty;
    return VocabWord(
      word: json['word'] as String,
      context: context,
      translation: json['translation'] as String?,
      description: json['description'] as String?,
      contextSource: hasContext
          ? (json['context_source'] as String? ?? 'photo')
          : null,
    );
  }
}
