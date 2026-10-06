import 'package:flutter/material.dart';

/// The small animation above the link field of the Quizlet link dialog: how
/// to get a set's link in Quizlet. A sketch of a set page, a finger that taps
/// Share, then Copy link, and a "Link copied" note, then points down at the
/// field. Each step is named under the sketch.
///
/// It plays [loops] times and then rests on its last step; a tap replays it.
/// [playing] false stops it at once on the last step (the field has text, so
/// the learner needs no more help). Drawn with plain widgets: no new packages.
class QuizletLinkHowTo extends StatefulWidget {
  const QuizletLinkHowTo({super.key, this.playing = true, this.loops = 3});

  final bool playing;
  final int loops;

  /// The sketch's height; kept small so the link field stays in sight with
  /// the keyboard up.
  static const double height = 130;

  /// How long one pass through the four steps takes.
  static const Duration period = Duration(milliseconds: 7000);

  /// The step names, in order; the last one stays when the animation rests.
  static const List<String> steps = [
    '1. Open the set in Quizlet',
    '2. Tap Share',
    '3. Tap Copy link',
    '4. Paste the link below',
  ];

  @override
  State<QuizletLinkHowTo> createState() => _QuizletLinkHowToState();
}

class _QuizletLinkHowToState extends State<QuizletLinkHowTo>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: QuizletLinkHowTo.period);

  int _played = 0;

  @override
  void initState() {
    super.initState();
    _controller.addStatusListener(_status);
    if (widget.playing) {
      _controller.forward();
    } else {
      _controller.value = 1;
    }
  }

  void _status(AnimationStatus status) {
    if (status != AnimationStatus.completed) return;
    _played++;
    if (widget.playing && _played < widget.loops) _controller.forward(from: 0);
  }

  @override
  void didUpdateWidget(QuizletLinkHowTo oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.playing && oldWidget.playing) {
      _controller
        ..stop()
        ..value = 1;
    }
  }

  void _replay() {
    if (!widget.playing) return;
    _played = widget.loops - 1;
    _controller.forward(from: 0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: const Key('quizlet-how-to'),
      onTap: _replay,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) => _frame(context, _controller.value),
      ),
    );
  }

  // The timeline of one pass, as fractions of [QuizletLinkHowTo.period].
  static const _toShare = (0.14, 0.30); // finger moves to Share
  static const _shareTap = 0.32;
  static const _sheetUp = (0.34, 0.42);
  static const _toCopy = (0.44, 0.58);
  static const _copyTap = 0.60;
  static const _sheetDown = (0.66, 0.72);
  static const _toField = (0.76, 0.92);

  static double _span(double t, (double, double) range) =>
      Curves.easeInOut.transform(
          ((t - range.$1) / (range.$2 - range.$1)).clamp(0.0, 1.0));

  static int _step(double t) {
    if (t < _toShare.$1) return 0;
    if (t < _sheetUp.$2) return 1;
    if (t < _sheetDown.$1) return 2;
    return 3;
  }

  /// A tap ring that grows and fades just after [at].
  static double _pulse(double t, double at) {
    final p = (t - at) / 0.05;
    return p < 0 || p > 1 ? 0 : p;
  }

  Widget _frame(BuildContext context, double t) {
    final scheme = Theme.of(context).colorScheme;
    final step = _step(t);
    final sheet = t < _sheetDown.$1
        ? _span(t, _sheetUp)
        : 1 - _span(t, _sheetDown);
    final copied = t >= _copyTap;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: QuizletLinkHowTo.height,
          child: LayoutBuilder(builder: (context, box) {
            final w = box.maxWidth;
            const h = QuizletLinkHowTo.height;
            // Where the finger points at each moment.
            final rest = Offset(w * 0.5, h + 10);
            final share = Offset(w - 22, 18);
            const copy = Offset(60, h - 33);
            final field = Offset(w * 0.5, h - 34);
            Offset finger;
            if (t < _toShare.$1) {
              finger = rest;
            } else if (t < _toCopy.$1) {
              finger = Offset.lerp(rest, share, _span(t, _toShare))!;
            } else if (t < _toField.$1) {
              finger = Offset.lerp(share, copy, _span(t, _toCopy))!;
            } else {
              finger = Offset.lerp(copy, field, _span(t, _toField))!;
            }
            final ring = _pulse(t, _shareTap) > 0
                ? _pulse(t, _shareTap)
                : _pulse(t, _copyTap);

            return Stack(
              clipBehavior: Clip.hardEdge,
              children: [
                Positioned.fill(child: _page(scheme, highlightShare: step == 1)),
                // The share sheet slides up from the bottom of the page.
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: -56 + 56 * sheet,
                  height: 56,
                  child: _sheet(scheme, copied: copied),
                ),
                if (copied && t < 0.98)
                  Positioned(
                    top: 44,
                    left: 0,
                    right: 0,
                    child: Center(child: _toast(scheme)),
                  ),
                if (ring > 0)
                  Positioned(
                    left: finger.dx - 6 - 14 * ring,
                    top: finger.dy - 6 - 14 * ring,
                    child: IgnorePointer(
                      child: Container(
                        width: 12 + 28 * ring,
                        height: 12 + 28 * ring,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: scheme.primary.withValues(alpha: 0.35 * (1 - ring)),
                        ),
                      ),
                    ),
                  ),
                if (step == 3)
                  Positioned(
                    left: field.dx + 16,
                    top: field.dy - 2,
                    child: Icon(Icons.arrow_downward,
                        size: 24,
                        color: scheme.primary
                            .withValues(alpha: _span(t, _toField))),
                  ),
                // The fingertip of touch_app sits near the icon's top middle.
                Positioned(
                  left: finger.dx - 14,
                  top: finger.dy - 4,
                  child: Icon(Icons.touch_app,
                      size: 30, color: scheme.onSurface.withValues(alpha: 0.85)),
                ),
              ],
            );
          }),
        ),
        const SizedBox(height: 8),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: Text(
            QuizletLinkHowTo.steps[step],
            key: ValueKey(step),
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      ],
    );
  }

  /// A sketch of a Quizlet set page: a top bar with Share and a few cards.
  Widget _page(ColorScheme scheme, {required bool highlightShare}) {
    final line = scheme.onSurface.withValues(alpha: 0.12);
    Widget bar(double width, {double height = 8}) => Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
              color: line, borderRadius: BorderRadius.circular(4)),
        );
    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border.all(color: scheme.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 36,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: const BoxDecoration(
              color: Color(0xFF4255FF),
              borderRadius: BorderRadius.vertical(top: Radius.circular(11)),
            ),
            child: Row(
              children: [
                const Icon(Icons.arrow_back, size: 18, color: Colors.white),
                const SizedBox(width: 8),
                Container(
                  width: 90,
                  height: 8,
                  decoration: BoxDecoration(
                      color: Colors.white70,
                      borderRadius: BorderRadius.circular(4)),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: highlightShare ? Colors.white30 : Colors.transparent,
                  ),
                  child: const Icon(Icons.ios_share,
                      size: 18, color: Colors.white),
                ),
              ],
            ),
          ),
          for (var i = 0; i < 3; i++)
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 10, 10, 0),
              child: Row(
                children: [
                  bar(46.0 + 14 * (i % 2)),
                  const SizedBox(width: 12),
                  Expanded(child: bar(double.infinity)),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _sheet(ColorScheme scheme, {required bool copied}) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        border: Border.all(color: scheme.outlineVariant),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: copied
                  ? scheme.primary.withValues(alpha: 0.15)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.link, size: 18),
                SizedBox(width: 6),
                Text('Copy link', style: TextStyle(fontSize: 13)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _toast(ColorScheme scheme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: scheme.inverseSurface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check, size: 14, color: scheme.onInverseSurface),
          const SizedBox(width: 4),
          Text('Link copied',
              style: TextStyle(fontSize: 12, color: scheme.onInverseSurface)),
        ],
      ),
    );
  }
}
