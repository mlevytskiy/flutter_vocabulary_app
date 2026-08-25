class WordPair {
  String word;
  String translation;

  WordPair({
    required this.word,
    required this.translation,
  });

  bool get isEmpty => word.trim().isEmpty && translation.trim().isEmpty;
  bool get isValid => word.trim().isNotEmpty && translation.trim().isNotEmpty;
}
