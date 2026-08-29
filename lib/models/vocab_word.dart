class VocabWord {
  final String word;
  final String? context;
  final String? translation;
  final String? description;

  VocabWord({
    required this.word,
    this.context,
    this.translation,
    this.description,
  });

  factory VocabWord.fromJson(Map<String, dynamic> json) {
    return VocabWord(
      word: json['word'] as String,
      context: json['context'] as String?,
      translation: json['translation'] as String?,
      description: json['description'] as String?,
    );
  }
}
