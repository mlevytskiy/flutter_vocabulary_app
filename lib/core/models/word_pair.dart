class WordPair {
  String word;
  String translation;

  WordPair({
    required this.word,
    required this.translation,
  });

  factory WordPair.fromJson(Map<String, dynamic> json) => WordPair(
        word: json['word'] as String? ?? '',
        translation: json['translation'] as String? ?? '',
      );

  Map<String, dynamic> toJson() => {
        'word': word,
        'translation': translation,
      };

  bool get isEmpty => word.trim().isEmpty && translation.trim().isEmpty;
  bool get isValid => word.trim().isNotEmpty && translation.trim().isNotEmpty;
}
