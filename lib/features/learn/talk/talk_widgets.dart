import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' show PathMetric;

import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderParagraph;

import '../../../core/models/word_pair.dart';
import '../../../core/theme/app_theme.dart';
import 'talk_text.dart';

/// The pieces of the Direction B talk screen (talk-screen-b, owner
/// 2026-10-24; design board https://claude.ai/artifact/V9mkcFBdK1DNeNDsRq4KrF):
/// the tutor header, the chat bubbles with their tappable practice words and
/// karaoke, the dashed live bubble, the pause ring, the small waveform and
/// the word strip's chips. Every colour comes from the theme and [AppDecor].

/// The word strip: one horizontal line of all the talk's words.
const talkStripKey = ValueKey('talk-strip');

/// The chat log's list.
const talkLogKey = ValueKey('talk-log');

/// The voice loading bar on the line about to be spoken, the player's
/// buttons and the mission card (talk-mission).
const talkVoiceLoadingKey = ValueKey('talk-voice-loading');
const talkPlayKey = ValueKey('talk-play');
const talkReplayKey = ValueKey('talk-replay');
const talkMissionKey = ValueKey('talk-mission');
const talkMissionPictureKey = ValueKey('talk-mission-picture');

/// The bubble of message [index].
ValueKey<String> talkBubbleKey(int index) => ValueKey('talk-bubble-$index');

/// [r] as the theme rounds its rows: Windows 95's square rows give square
/// bubbles, Amber Terminal's 2 px rows nearly square ones.
double talkRound(AppDecor decor, double r) => math.min(r, decor.wordRowRadius * 2);

/// Who the learner talks to: a gradient monogram and "Emma — Your English
/// partner · <collection>", with End talk on the right.
class TalkTutorHeader extends StatelessWidget {
  const TalkTutorHeader({super.key, required this.collectionName, required this.onEnd});

  final String collectionName;

  /// End talk; null while there is nothing to end.
  final VoidCallback? onEnd;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final decor = AppDecor.of(context);
    final subtitle =
        collectionName.trim().isEmpty ? 'Your English partner' : 'Your English partner · ${collectionName.trim()}';
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 6, 8, 10),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: scheme.outlineVariant))),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(talkRound(decor, 19)),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color.lerp(scheme.primary, scheme.surface, 0.45)!, scheme.primary],
              ),
            ),
            child: Text(
              'E',
              style: (theme.textTheme.titleLarge ?? const TextStyle())
                  .copyWith(color: scheme.onPrimary, fontSize: 16, fontWeight: FontWeight.w700, height: 1),
              textScaler: TextScaler.noScaling,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Emma', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800, height: 1.2)),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(color: decor.muted, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          TextButton(onPressed: onEnd, child: const Text('End talk')),
        ],
      ),
    );
  }
}

/// One message: the AI's on the left on a soft surface with a small
/// bottom-left corner, the learner's on the right in the accent colour. The
/// talk's [words] are highlighted — accent, bold, dotted underline; used ones
/// in the "used" colour — and a tap on one calls [onWord] with where it was
/// tapped. With [spokenEnd] the AI's line is being read: the part after it is
/// faded until the voice reaches it (karaoke).
class TalkBubble extends StatefulWidget {
  const TalkBubble({
    super.key,
    required this.index,
    required this.text,
    required this.mine,
    required this.maxWidth,
    this.words = const [],
    this.usedRows = const {},
    this.spokenEnd,
    this.voiceLoading = false,
    this.voiceProgress = 0,
    this.onWord,
    this.onOtherWord,
    this.onPhrase,
  });

  final int index;
  final String text;
  final bool mine;
  final double maxWidth;
  final List<WordPair> words;
  final Set<String> usedRows;
  final int? spokenEnd;

  /// Whether this line's voice is being fetched: a thin running bar along the
  /// bubble's top edge, the text left as it is (talk-mission, owner
  /// 2026-10-24).
  final bool voiceLoading;

  /// How far that bar has filled, 0 to 1.
  final double voiceProgress;

  /// A tap on a practice word, with the tapped word's place on screen, so
  /// the popup points at the word itself.
  final void Function(WordPair word, Rect globalRect)? onWord;

  /// A tap on any other word of an AI line, with the word and its place on
  /// screen, to look its translation up (owner, 2026-10-24).
  final void Function(String word, Rect globalRect)? onOtherWord;

  /// A long press dragged over several words of an AI line: the words from
  /// the first to the last touched, and their place on screen, to translate
  /// together (owner, 2026-10-24).
  final void Function(String phrase, Rect globalRect)? onPhrase;

  @override
  State<TalkBubble> createState() => _TalkBubbleState();
}

class _TalkBubbleState extends State<TalkBubble> {
  /// One recognizer per practice word, made on first use, freed with the
  /// bubble.
  final _taps = <String, TapGestureRecognizer>{};
  final _textKey = GlobalKey();

  /// Where each practice word sits in the text, from the last build.
  var _ranges = <(int, int, String)>[];

  /// One recognizer per other word of an AI line, keyed by where the word
  /// starts in the text, so a word the karaoke cuts in two keeps one.
  final _otherTaps = <int, TapGestureRecognizer>{};

  TapGestureRecognizer _otherTapFor(int start, int end) => _otherTaps.putIfAbsent(
        start,
        () => TapGestureRecognizer()
          ..onTapUp = (_) {
            final cb = widget.onOtherWord;
            if (cb != null) cb(widget.text.substring(start, end), _rangeRect([(start, end)], null));
          },
      );

  /// The long-press selection: the word it started on and the word under
  /// the finger now (indexes into [_tokens]); null when there is none.
  int? _selFrom;
  int? _selTo;

  /// Every word of the line, by place in the text.
  List<(int, int)> get _tokens => [for (final m in _otherWord.allMatches(widget.text)) (m.start, m.end)];

  /// The word under (or nearest before) [global], as an index into [tokens].
  int? _tokenAt(Offset global, List<(int, int)> tokens) {
    final paragraph = _textKey.currentContext?.findRenderObject();
    if (paragraph is! RenderParagraph || !paragraph.attached || tokens.isEmpty) return null;
    final offset = paragraph.getPositionForOffset(paragraph.globalToLocal(global)).offset;
    var best = 0;
    for (final (i, (start, _)) in tokens.indexed) {
      if (start <= offset) best = i;
    }
    return best;
  }

  /// The selected text range, from the first to the last touched word.
  (int, int)? get _selRange {
    final (a, b) = (_selFrom, _selTo);
    if (a == null || b == null) return null;
    final tokens = _tokens;
    final (lo, hi) = a <= b ? (a, b) : (b, a);
    return (tokens[lo].$1, tokens[hi].$2);
  }

  void _selStart(LongPressStartDetails d) {
    final at = _tokenAt(d.globalPosition, _tokens);
    if (at == null) return;
    HapticFeedback.selectionClick();
    setState(() => _selFrom = _selTo = at);
  }

  void _selMove(LongPressMoveUpdateDetails d) {
    if (_selFrom == null) return;
    final at = _tokenAt(d.globalPosition, _tokens);
    if (at != null && at != _selTo) {
      HapticFeedback.selectionClick();
      setState(() => _selTo = at);
    }
  }

  void _selEnd([LongPressEndDetails? _]) {
    final range = _selRange;
    setState(() => _selFrom = _selTo = null);
    final cb = widget.onPhrase;
    if (range == null || cb == null) return;
    cb(widget.text.substring(range.$1, range.$2), _unionRect(range.$1, range.$2));
  }

  /// The boxes of the text range [start]–[end], in the paragraph's own space.
  List<Rect> _boxes(int start, int end) {
    final paragraph = _textKey.currentContext?.findRenderObject();
    if (paragraph is! RenderParagraph || !paragraph.attached) return const [];
    return [
      for (final b in paragraph.getBoxesForSelection(TextSelection(baseOffset: start, extentOffset: end))) b.toRect(),
    ];
  }

  /// The range's boxes joined, on screen: where the popup points.
  Rect _unionRect(int start, int end) {
    final paragraph = _textKey.currentContext?.findRenderObject();
    final boxes = _boxes(start, end);
    if (paragraph is! RenderParagraph || boxes.isEmpty) return Rect.zero;
    final all = boxes.reduce((a, b) => a.expandToInclude(b));
    return paragraph.localToGlobal(all.topLeft) & all.size;
  }

  @override
  void didUpdateWidget(TalkBubble old) {
    super.didUpdateWidget(old);
    if (old.text != widget.text) {
      for (final t in _otherTaps.values) {
        t.dispose();
      }
      _otherTaps.clear();
    }
  }

  TapGestureRecognizer _tapFor(WordPair w) => _taps.putIfAbsent(
        w.rowId,
        () => TapGestureRecognizer()
          ..onTapUp = (d) {
            final word = widget.words.where((x) => x.rowId == w.rowId).firstOrNull;
            if (word != null) widget.onWord?.call(word, _wordRect(w.rowId, d.globalPosition));
          },
      );

  /// The tapped word's box on screen: of the word's places in the text, the
  /// one under (or nearest) the tap; the tap's spot when the text is not
  /// laid out.
  Rect _wordRect(String rowId, Offset tap) => _rangeRect([
        for (final (start, end, id) in _ranges)
          if (id == rowId) (start, end)
      ], tap);

  /// The box on screen of the text range of [ranges] under (or nearest)
  /// [tap] — the first one without a tap.
  Rect _rangeRect(List<(int, int)> ranges, Offset? tap) {
    final fallback = tap == null ? Rect.zero : Rect.fromCenter(center: tap, width: 24, height: 22);
    final paragraph = _textKey.currentContext?.findRenderObject();
    if (paragraph is! RenderParagraph || !paragraph.attached) return fallback;
    final local = tap == null ? null : paragraph.globalToLocal(tap);
    Rect? best;
    var bestDistance = double.infinity;
    for (final (start, end) in ranges) {
      for (final box in paragraph.getBoxesForSelection(TextSelection(baseOffset: start, extentOffset: end))) {
        final r = box.toRect();
        final distance = local == null ? 0.0 : (r.inflate(4).contains(local) ? 0.0 : (r.center - local).distance);
        if (local == null && best != null) continue;
        if (distance < bestDistance) (best, bestDistance) = (r, distance);
      }
    }
    if (best == null) return fallback;
    return paragraph.localToGlobal(best.topLeft) & best.size;
  }

  @override
  void dispose() {
    for (final t in [..._taps.values, ..._otherTaps.values]) {
      t.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final decor = AppDecor.of(context);
    final mine = widget.mine;
    final ink = mine ? scheme.onPrimary : scheme.onSurface;
    final base = (theme.textTheme.bodyLarge ?? const TextStyle()).copyWith(color: ink, fontSize: 15.5, height: 1.45);
    final speaking = widget.spokenEnd != null;
    Color fade(Color c) => c.withValues(alpha: c.a * 0.4);

    TextStyle styleOf(TalkSpan s) {
      var style = base;
      final w = s.word;
      if (w != null) {
        final used = widget.usedRows.contains(w.rowId);
        final colour = mine ? scheme.onPrimary : (used ? decor.learnRight : scheme.primary);
        style = style.copyWith(
          color: colour,
          fontWeight: FontWeight.w700,
          decoration: TextDecoration.underline,
          decorationStyle: mine ? TextDecorationStyle.solid : TextDecorationStyle.dotted,
          decorationColor: mine ? decor.learnRight : colour,
          decorationThickness: mine ? 2 : 1.6,
        );
      }
      return s.spoken ? style : style.copyWith(color: fade(style.color ?? ink));
    }

    final r = talkRound(decor, 18);
    final small = talkRound(decor, 6);
    final spans = talkSpans(widget.text, widget.words, spokenEnd: widget.spokenEnd);
    final ranges = <(int, int, String)>[];
    var at = 0;
    for (final s in spans) {
      if (s.word != null) ranges.add((at, at + s.text.length, s.word!.rowId));
      at += s.text.length;
    }
    _ranges = ranges;
    // The other words of an AI line, tappable for a translation.
    final others = !mine && widget.onOtherWord != null
        ? [for (final m in _otherWord.allMatches(widget.text)) (m.start, m.end)]
        : const <(int, int)>[];
    List<TextSpan> pieces(TalkSpan s, int from) {
      final style = styleOf(s);
      if (s.word != null || others.isEmpty) {
        return [
          TextSpan(
            text: s.text,
            style: style,
            recognizer: s.word != null && widget.onWord != null ? _tapFor(s.word!) : null,
          ),
        ];
      }
      final to = from + s.text.length;
      final out = <TextSpan>[];
      var at = from;
      for (final (start, end) in others) {
        if (end <= from || start >= to) continue;
        final a = start < from ? from : start;
        final b = end > to ? to : end;
        if (a > at) out.add(TextSpan(text: widget.text.substring(at, a), style: style));
        out.add(TextSpan(text: widget.text.substring(a, b), style: style, recognizer: _otherTapFor(start, end)));
        at = b;
      }
      if (at < to) out.add(TextSpan(text: widget.text.substring(at, to), style: style));
      return out;
    }

    final rich = <TextSpan>[];
    var from = 0;
    for (final s in spans) {
      rich.addAll(pieces(s, from));
      from += s.text.length;
    }
    final shape = BorderRadius.only(
      topLeft: Radius.circular(r),
      topRight: Radius.circular(r),
      bottomLeft: Radius.circular(mine ? r : small),
      bottomRight: Radius.circular(mine ? small : r),
    );
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        key: talkBubbleKey(widget.index),
        margin: const EdgeInsets.symmetric(vertical: 5),
        constraints: BoxConstraints(maxWidth: widget.maxWidth),
        decoration: BoxDecoration(
          color: mine ? scheme.primary : scheme.surfaceContainerHighest,
          border: speaking ? Border.all(color: scheme.primary.withValues(alpha: 0.55), width: 1.5) : null,
          borderRadius: shape,
        ),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: GestureDetector(
                // Long press and drag: highlight several words to translate them together.
                onLongPressStart: !mine && widget.onPhrase != null ? _selStart : null,
                onLongPressMoveUpdate: !mine && widget.onPhrase != null ? _selMove : null,
                onLongPressEnd: !mine && widget.onPhrase != null ? _selEnd : null,
                onLongPressCancel: _selFrom == null ? null : () => setState(() => _selFrom = _selTo = null),
                child: Stack(
                  children: [
                    Text.rich(
                      key: _textKey,
                      TextSpan(children: rich),
                      style: base,
                    ),
                    if (_selRange case final range?)
                      Positioned.fill(
                        child: IgnorePointer(
                          child: CustomPaint(
                            key: talkSelectionKey,
                            painter: _SelectionPainter(
                              boxes: _boxes(range.$1, range.$2),
                              color: scheme.primary.withValues(alpha: 0.28),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              top: 0,
              child: ClipRRect(
                borderRadius: BorderRadius.only(topLeft: Radius.circular(r), topRight: Radius.circular(r)),
                child: AnimatedOpacity(
                  opacity: widget.voiceLoading ? 1 : 0,
                  duration: const Duration(milliseconds: 150),
                  child: LinearProgressIndicator(
                    key: widget.voiceLoading ? talkVoiceLoadingKey : null,
                    minHeight: 3,
                    backgroundColor: scheme.primary.withValues(alpha: 0.12),
                    color: scheme.primary,
                    value: widget.voiceProgress.clamp(0.0, 1.0),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Play/Stop and Replay under the latest AI line, like a player's controls
/// (talk-mission, owner 2026-10-24). While the voice is fetched the play
/// button is already Stop; the bubble's bar shows the loading.
class TalkVoiceControls extends StatelessWidget {
  const TalkVoiceControls({
    super.key,
    required this.speaking,
    required this.onPlay,
    required this.onStop,
    required this.onReplay,
  });

  final bool speaking;

  /// Null while the line cannot be played (the learner is speaking).
  final VoidCallback? onPlay;
  final VoidCallback onStop;
  final VoidCallback? onReplay;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final decor = AppDecor.of(context);
    final ink = speaking ? scheme.primary : decor.muted;
    const size = BoxConstraints.tightFor(width: 40, height: 40);
    return Padding(
      padding: const EdgeInsets.only(left: 2, bottom: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            key: talkPlayKey,
            tooltip: speaking ? 'Stop' : 'Play',
            constraints: size,
            padding: EdgeInsets.zero,
            iconSize: 24,
            color: ink,
            onPressed: speaking ? onStop : onPlay,
            icon: Icon(speaking ? Icons.stop_rounded : Icons.play_arrow_rounded),
          ),
          IconButton(
            key: talkReplayKey,
            tooltip: 'Replay',
            constraints: size,
            padding: EdgeInsets.zero,
            iconSize: 22,
            color: decor.muted,
            onPressed: onReplay,
            icon: const Icon(Icons.replay_rounded),
          ),
        ],
      ),
    );
  }
}

/// The mission at the top of the talk (talk-mission, owner 2026-10-24): its
/// 16:9 opening picture — a quiet tinted slot while it is drawn (no loader,
/// owner 2026-10-24), faded in once it comes, left out when it never does — then the title, the learner's
/// role and the goal.
class TalkMissionCard extends StatelessWidget {
  const TalkMissionCard({
    super.key,
    required this.title,
    required this.role,
    required this.goal,
    required this.picture,
    required this.pictureLoading,
  });

  final String title;
  final String role;
  final String goal;
  final Uint8List? picture;
  final bool pictureLoading;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final decor = AppDecor.of(context);
    final r = talkRound(decor, 16);
    final bytes = picture;
    final line = theme.textTheme.bodyMedium?.copyWith(height: 1.35);
    Widget row(IconData icon, String text) => Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Padding(
              padding: const EdgeInsets.only(top: 1),
              child: Icon(icon, size: 18, color: scheme.primary),
            ),
            const SizedBox(width: 8),
            Expanded(child: Text(text, style: line)),
          ]),
        );
    return Container(
      key: talkMissionKey,
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(r),
        border: Border.all(color: scheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (bytes != null || pictureLoading)
            AspectRatio(
              aspectRatio: 16 / 9,
              child: Stack(fit: StackFit.expand, children: [
                ColoredBox(color: scheme.surfaceContainerHighest),
                if (bytes != null)
                  Image.memory(
                    bytes,
                    key: talkMissionPictureKey,
                    fit: BoxFit.cover,
                    gaplessPlayback: true,
                    frameBuilder: (_, child, frame, sync) => AnimatedOpacity(
                      opacity: sync || frame != null ? 1 : 0,
                      duration: const Duration(milliseconds: 400),
                      curve: Curves.easeOut,
                      child: child,
                    ),
                  ),
              ]),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                row(Icons.person_outline_rounded, role),
                row(Icons.flag_outlined, goal),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The long-press highlight over the words being picked.
const talkSelectionKey = ValueKey('talk-selection');

class _SelectionPainter extends CustomPainter {
  const _SelectionPainter({required this.boxes, required this.color});

  final List<Rect> boxes;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    for (final b in boxes) {
      canvas.drawRRect(RRect.fromRectAndRadius(b.inflate(2), const Radius.circular(4)), paint);
    }
  }

  @override
  bool shouldRepaint(_SelectionPainter old) => old.boxes != boxes || old.color != color;
}

/// A word in an AI line: letters, with inner apostrophes and hyphens.
final _otherWord = RegExp(r"[\p{L}]+(?:['’-][\p{L}]+)*", unicode: true);

/// The words being heard, in a dashed accent outline on the learner's side.
class TalkLiveBubble extends StatelessWidget {
  const TalkLiveBubble({super.key, required this.text, required this.maxWidth});

  final String text;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final decor = AppDecor.of(context);
    final r = talkRound(decor, 18);
    final shape = BorderRadius.only(
      topLeft: Radius.circular(r),
      topRight: Radius.circular(r),
      bottomLeft: Radius.circular(r),
      bottomRight: Radius.circular(talkRound(decor, 6)),
    );
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 5),
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: CustomPaint(
          painter: _DashedBubble(color: scheme.primary, shape: shape),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Text(
              text,
              style: (theme.textTheme.bodyLarge ?? const TextStyle())
                  .copyWith(color: scheme.onSurface, fontSize: 15.5, height: 1.45),
            ),
          ),
        ),
      ),
    );
  }
}

/// A 1.5 px dashed outline of [shape] (the dashes of `DashedAddButton`).
class _DashedBubble extends CustomPainter {
  const _DashedBubble({required this.color, required this.shape});

  final Color color;
  final BorderRadius shape;

  static const _dash = 5.0;
  static const _gap = 4.0;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final outline = Path()..addRRect(shape.toRRect((Offset.zero & size).deflate(0.75)));
    for (final PathMetric metric in outline.computeMetrics()) {
      for (var d = 0.0; d < metric.length; d += _dash + _gap) {
        canvas.drawPath(metric.extractPath(d, d + _dash), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBubble old) => old.color != color || old.shape != shape;
}

/// The mic and the ring around it, twice their first size (owner,
/// 2026-10-24).
const double talkMicSize = 104;
const double talkRingSize = 132;

/// One tap answer of a mixed mission's choice turn (talk-mixed), its
/// practice words bold with a dotted underline. [detail], when given, is a
/// small line under the choice (learn-welcome's warm-up topics).
class TalkChoiceButton extends StatelessWidget {
  const TalkChoiceButton({super.key, required this.choice, this.words = const [], required this.onPressed, this.detail});

  final String choice;
  final List<WordPair> words;
  final VoidCallback? onPressed;
  final String? detail;

  @override
  Widget build(BuildContext context) {
    final label = Text.rich(
      TextSpan(children: [
        for (final part in talkSpans(choice, words))
          TextSpan(
            text: part.text,
            style: part.word == null
                ? null
                : const TextStyle(
                    fontWeight: FontWeight.w800,
                    decoration: TextDecoration.underline,
                    decorationStyle: TextDecorationStyle.dotted,
                  ),
          ),
      ]),
      textAlign: TextAlign.center,
    );
    final more = detail;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: OutlinedButton(
        onPressed: onPressed,
        child: more == null
            ? label
            : Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  label,
                  const SizedBox(height: 2),
                  Text(
                    more,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppDecor.of(context).muted),
                  ),
                ]),
              ),
      ),
    );
  }
}

/// The round mic itself, inside [TalkRing]: filled in the accent while
/// listening ([on]), faded while the talk is [busy].
class TalkMicCircle extends StatelessWidget {
  const TalkMicCircle({super.key, required this.on, this.busy = false});

  final bool on;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final micOn = on;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: talkMicSize,
      height: talkMicSize,
      decoration: BoxDecoration(
        color: micOn
            ? scheme.primary
            : scheme.primaryContainer.withValues(alpha: busy ? 0.38 : 1),
        // Round in every theme (owner, 2026-10-24).
        shape: BoxShape.circle,
      ),
      child: Icon(
        micOn ? Icons.mic : Icons.mic_none,
        size: 46,
        color: micOn
            ? scheme.onPrimary
            : scheme.onPrimaryContainer.withValues(alpha: busy ? 0.38 : 1),
      ),
    );
  }
}

/// The ring around the mic: its track while listening, filling as the
/// learner's pause runs down to sending ([progress] 0–1).
class TalkRing extends StatelessWidget {
  const TalkRing({super.key, required this.progress, required this.active, required this.child});

  final double progress;
  final bool active;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: talkRingSize,
      height: talkRingSize,
      child: CustomPaint(
        painter: _RingPainter(
          track: active ? scheme.outlineVariant : Colors.transparent,
          fill: scheme.tertiary,
          progress: active ? progress : 0,
        ),
        child: Center(child: child),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter({required this.track, required this.fill, required this.progress});

  final Color track;
  final Color fill;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 6.0;
    final rect = (Offset.zero & size).deflate(stroke / 2);
    canvas.drawArc(
        rect,
        0,
        2 * math.pi,
        false,
        Paint()
          ..color = track
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke);
    if (progress <= 0) return;
    canvas.drawArc(
        rect,
        -math.pi / 2,
        2 * math.pi * progress.clamp(0, 1),
        false,
        Paint()
          ..color = fill
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = stroke);
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.progress != progress || old.track != track || old.fill != fill;
}

/// Six small bars beside the mic while it listens; they move with each new
/// piece of what is heard ([seed]), so they follow the voice without a
/// running animation.
class TalkWave extends StatelessWidget {
  const TalkWave({super.key, required this.active, required this.seed});

  final bool active;
  final int seed;

  @override
  Widget build(BuildContext context) {
    final colour = Theme.of(context).colorScheme.primary;
    final random = math.Random(seed);
    return AnimatedOpacity(
      opacity: active ? 1 : 0,
      duration: const Duration(milliseconds: 200),
      child: SizedBox(
        height: 22,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < 6; i++)
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOut,
                margin: const EdgeInsets.symmetric(horizontal: 1.5),
                width: 3,
                height: 22 * (seed == 0 ? 0.3 : 0.3 + 0.7 * random.nextDouble()),
                decoration: BoxDecoration(color: colour, borderRadius: BorderRadius.circular(2)),
              ),
          ],
        ),
      ),
    );
  }
}

/// One word of the strip: ticked in the "used" colour, the word the AI steers
/// to outlined in the accent, the rest quiet. A tap calls [onTap] with the
/// chip's place on screen.
class TalkStripChip extends StatelessWidget {
  const TalkStripChip({super.key, required this.word, required this.used, required this.target, required this.onTap});

  final String word;
  final bool used;
  final bool target;
  final void Function(Rect globalRect) onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final decor = AppDecor.of(context);
    final colour = used ? decor.onLearnRight : (target ? scheme.primary : decor.muted);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        final box = context.findRenderObject() as RenderBox?;
        if (box == null || !box.hasSize) return;
        onTap(box.localToGlobal(Offset.zero) & box.size);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 4),
        decoration: BoxDecoration(
          color: used ? decor.learnRight : null,
          borderRadius: BorderRadius.circular(talkRound(decor, 999)),
          border: used ? null : Border.all(color: target ? scheme.primary : scheme.outlineVariant, width: 1.5),
        ),
        child: Text(
          used ? '$word ✓' : word,
          style: theme.textTheme.labelLarge?.copyWith(color: colour, fontWeight: FontWeight.w700, fontSize: 13),
        ),
      ),
    );
  }
}
