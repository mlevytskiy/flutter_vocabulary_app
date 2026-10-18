/// Where a collection's name — or its description — came from
/// (collection-naming, owner 2026-10-18).
/// Stored by ordinal, so the order is fixed — [undefined] first, which is
/// also what a record from before reads as — and a new kind is only appended.
enum NameKind {
  /// Nobody named it and it has fewer than [minWordsForAutoName] words (or
  /// the AI has not answered yet): "Vocabulary", "Vocabulary 1", …
  undefined,

  /// The AI's short name for its words, asked for once it reached
  /// [minWordsForAutoName] words.
  auto,

  /// Typed by the learner; never replaced.
  byUser,
}

/// How many words a collection needs before the AI is asked for its name.
const minWordsForAutoName = 5;

/// How many words a collection needs before the AI is asked for its
/// description, when the learner gave none (owner, 2026-10-18). Until then
/// the description stays empty.
const minWordsForAutoDescription = 20;
