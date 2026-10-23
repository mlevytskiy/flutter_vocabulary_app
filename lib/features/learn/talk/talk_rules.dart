import '../../../core/dialogues/dialogue_match.dart';
import '../../../core/models/word_pair.dart';
import '../../../core/services/talk_api_service.dart' show TalkLine;
import '../session/leitner.dart';

/// The pure rules of Talk with AI (learn-redesign AC-20 – AC-22, ADR-0008).
/// The app, never the AI, decides which words were used.

/// A talk ends by itself after this many learner replies (AC-20).
const int talkMaxReplies = 12;

/// The Hint shows after this many learner replies without the target (AC-21).
const int talkHintAfter = 2;

/// The most lines a reply turn sends (ADR-0007).
const int talkMaxHistory = 24;

/// Row ids of [words] that [learnerText] uses, by the exercises' whole-word
/// rule ([matchPlaces], ADR-0008). Only ever called with the learner's own
/// text (AC-21).
Set<String> usedWords(String learnerText, List<WordPair> words) => {
      for (final w in words)
        if (matchPlaces(learnerText, w.word).isNotEmpty) w.rowId,
    };

/// Whether the Hint is offered: after [talkHintAfter] learner replies without
/// the targeted word (AC-21).
bool hintDue(int repliesWithoutTarget) => repliesWithoutTarget >= talkHintAfter;

/// The talk's scene from text already stored (AC-20): the group's mnemonic
/// story, else a film dialogue's lines, else the collection's name and
/// description. Blank texts are skipped.
String scenePick({String? storyText, String? dialogueText, required String name, String description = ''}) {
  if (storyText != null && storyText.trim().isNotEmpty) return storyText.trim();
  if (dialogueText != null && dialogueText.trim().isNotEmpty) return dialogueText.trim();
  final d = description.trim();
  return d.isEmpty ? name.trim() : '${name.trim()}\n$d';
}

/// How each talk word ends (AC-22): used without its hint → clean, used after
/// its hint → missed, never used → unused (box and next review kept). Keyed
/// by the [words] instances, as [applySession] wants.
Map<WordPair, WordOutcome> scoreTalk(List<WordPair> words, {required Set<String> used, required Set<String> hinted}) => {
      for (final w in words)
        w: !used.contains(w.rowId)
            ? WordOutcome.unused
            : hinted.contains(w.rowId)
                ? WordOutcome.missed
                : WordOutcome.clean,
    };

/// Whether the talk ends by itself (AC-20): [talkMaxReplies] learner replies,
/// or every one of its words used.
bool talkOver(int learnerReplies, int usedCount, int wordCount) =>
    learnerReplies >= talkMaxReplies || (wordCount > 0 && usedCount >= wordCount);

/// The latest [talkMaxHistory] lines of [history] (ADR-0007).
List<TalkLine> capHistory(List<TalkLine> history) =>
    history.length <= talkMaxHistory ? history : history.sublist(history.length - talkMaxHistory);
