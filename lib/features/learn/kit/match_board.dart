import 'dart:math';

import 'package:flutter/material.dart';

/// One card of a match board (learn-match-synonyms S-35): [id] is unique in
/// its column and opaque to the board; [hint] shows on a long press (S-36),
/// null shows nothing.
class MatchItem {
  const MatchItem({required this.id, required this.text, this.hint});

  final String id;
  final String text;
  final String? hint;
}

final _sentenceEnd = RegExp(r'[.!?](?=\s|$)');

/// Card text (S-37, D-10): [text] up to [max] characters is unchanged; longer
/// is cut at the end of its first sentence when that is within [max], else at
/// the last whole word within [max] plus "…".
String cardText(String text, {int max = 120}) {
  if (text.length <= max) return text;
  final end = _sentenceEnd.firstMatch(text);
  if (end != null && end.end <= max) return text.substring(0, end.end);
  final head = text.substring(0, max);
  var body = head;
  if (!RegExp(r'\s').hasMatch(text[max])) {
    final space = head.lastIndexOf(RegExp(r'\s'));
    if (space > 0) body = head.substring(0, space);
  }
  return '${body.trimRight()}…';
}

/// A word's misses in a match round's summary (S-37), used as `WordOutcome.result`.
String missesText(int n) => switch (n) {
      0 => 'no misses',
      1 => '1 miss',
      _ => '$n misses',
    };

/// The two-column round of the match exercises (learn-match-synonyms S-35,
/// S-36; D-01). [left] and [right] show in the order given (the caller
/// shuffles [right]); [links] are the locked pairs leftId → rightId in the
/// order they were made, each shown with its pair number.
///
/// The board never decides right or wrong: once one unlocked card of each
/// column is selected it calls [onPair] once. `true` means the caller added
/// the link (the board clears its selection), `false` that the caller counted
/// a miss (both cards shake once and are unselected). Only the selection and
/// the shake live here; the caller keys the board by round so a new round
/// starts fresh.
class MatchBoard extends StatefulWidget {
  // Not const: the asserts read the lists' lengths.
  // ignore: prefer_const_constructors_in_immutables
  MatchBoard({
    super.key,
    required this.left,
    required this.right,
    required this.links,
    required this.onPair,
  })  : assert(left.length == right.length, 'both columns hold the same number of cards'),
        assert(left.length >= 3 && left.length <= 6, 'a round holds 3 to 6 pairs');

  final List<MatchItem> left;
  final List<MatchItem> right;
  final Map<String, String> links;
  final bool Function(String leftId, String rightId) onPair;

  @override
  State<MatchBoard> createState() => _MatchBoardState();
}

class _MatchBoardState extends State<MatchBoard> with SingleTickerProviderStateMixin {
  String? _left;
  String? _right;
  Set<String> _shaking = const {};
  late final AnimationController _shake = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 300),
  )..addStatusListener((status) {
      if (status == AnimationStatus.completed) setState(() => _shaking = const {});
    });

  @override
  void dispose() {
    _shake.dispose();
    super.dispose();
  }

  bool _leftLocked(String id) => widget.links.containsKey(id);
  bool _rightLocked(String id) => widget.links.containsValue(id);

  void _tap({required bool left, required String id}) {
    if (left ? _leftLocked(id) : _rightLocked(id)) return;
    setState(() {
      if (left) {
        _left = _left == id ? null : id;
      } else {
        _right = _right == id ? null : id;
      }
    });
    final (l, r) = (_left, _right);
    if (l == null || r == null) return;
    final linked = widget.onPair(l, r);
    setState(() {
      _left = null;
      _right = null;
      if (!linked) _shaking = {'l:$l', 'r:$r'};
    });
    if (!linked) _shake.forward(from: 0);
  }

  double _offset(String key) {
    if (!_shaking.contains(key)) return 0;
    final t = _shake.value;
    return sin(t * 6 * pi) * 8 * (1 - t);
  }

  @override
  Widget build(BuildContext context) {
    final numbers = <String, int>{};
    final rightNumbers = <String, int>{};
    var n = 0;
    for (final link in widget.links.entries) {
      n++;
      numbers[link.key] = n;
      rightNumbers[link.value] = n;
    }
    return AnimatedBuilder(
      animation: _shake,
      builder: (context, _) => SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < widget.left.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(child: _card(widget.left[i], left: true, number: numbers[widget.left[i].id])),
                      const SizedBox(width: 8),
                      Expanded(child: _card(widget.right[i], left: false, number: rightNumbers[widget.right[i].id])),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _card(MatchItem item, {required bool left, required int? number}) => MatchCard(
        key: ValueKey('match-${left ? 'left' : 'right'}-${item.id}'),
        text: item.text,
        hint: item.hint,
        selected: number == null && (left ? _left : _right) == item.id,
        pairNumber: number,
        shake: _offset('${left ? 'l' : 'r'}:${item.id}'),
        onTap: () => _tap(left: left, id: item.id),
      );
}

/// One card of [MatchBoard]: plain wrapping text, a pair number once linked
/// (then it looks done and takes no taps), the hint on a long press. A long
/// press never counts as a tap, hint or not.
class MatchCard extends StatefulWidget {
  const MatchCard({
    super.key,
    required this.text,
    required this.hint,
    required this.selected,
    required this.pairNumber,
    required this.shake,
    required this.onTap,
  });

  final String text;
  final String? hint;
  final bool selected;
  final int? pairNumber;

  /// Horizontal offset of the wrong-pair shake; 0 at rest.
  final double shake;
  final VoidCallback onTap;

  @override
  State<MatchCard> createState() => _MatchCardState();
}

class _MatchCardState extends State<MatchCard> {
  final _tooltip = GlobalKey<TooltipState>();

  @override
  Widget build(BuildContext context) {
    final MatchCard(:text, :hint, :selected, :pairNumber, :shake, :onTap) = widget;
    final scheme = Theme.of(context).colorScheme;
    final done = pairNumber != null;
    final radius = BorderRadius.circular(8);
    Widget card = Material(
      color: done
          ? scheme.surfaceContainerHighest
          : selected
              ? scheme.primaryContainer
              : scheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: BorderSide(
          color: selected ? scheme.primary : scheme.outlineVariant,
          width: selected ? 2 : 1,
        ),
      ),
      child: InkWell(
        borderRadius: radius,
        onTap: done ? null : onTap,
        onLongPress: () => _tooltip.currentState?.ensureTooltipVisible(),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              if (done) ...[
                CircleAvatar(
                  radius: 12,
                  backgroundColor: scheme.secondary,
                  foregroundColor: scheme.onSecondary,
                  child: Text('$pairNumber', style: const TextStyle(fontSize: 12)),
                ),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: Text(
                  text,
                  style: TextStyle(
                    color: done
                        ? scheme.onSurfaceVariant
                        : selected
                            ? scheme.onPrimaryContainer
                            : scheme.onSurface,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (hint != null && hint.isNotEmpty) {
      card = Tooltip(key: _tooltip, message: hint, triggerMode: TooltipTriggerMode.manual, child: card);
    }
    return Semantics(
      container: true,
      child: Transform.translate(offset: Offset(shake, 0), child: card),
    );
  }
}
