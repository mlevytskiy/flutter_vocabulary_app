import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

import 'animated_bolt_icon.dart' show BoltState;

/// Lottie-powered drop-in replacement for [AnimatedBoltIcon] (see
/// `animated_bolt_icon.dart`, kept in the repo unused as a rollback option).
///
/// Concept: "lightning shatters into stars", driven by two chained async
/// calls (translate, then a currently-mocked "additional info" fetch) and
/// played back as named segments of one of five pre-baked Lottie
/// compositions (`assets/animations/bolt_shatter_stars_{0,2,3,4,5}.json` --
/// note there is no `_1` variant, 1 star is never a valid outcome -- picked
/// by [starCount]; see `tool/generate_bolt_shatter_lottie.py` for how
/// they're authored):
///
/// - `idle_to_broken` — the bolt shatters into 16 fragments (once), landing
///   in a hand-art-directed, asymmetric/varied-size debris layout rather
///   than an evenly-spaced ring.
/// - `broken_loop` — a seamless loop of the 16 fragments gently wiggling in
///   place, held for as long as call #1 (translate) is in flight.
/// - `searching_star_loop` — a seamless loop where a single small star
///   wanders along a closed Lissajous curve. Entering this segment, 10 of
///   the 16 fragments fade away; the other 6 stay visible (subtly
///   twinkling) around the wandering star for as long as call #2
///   ("additional info") is in flight.
/// - `broken_to_stars` — of the 6 surviving fragments, [starCount] of them
///   shrink away while a fully-formed star grows/fades in at the same spot
///   (a bloom, not a disappear/reveal); the rest give a brief "poof" and
///   dissolve to nothing -- including all 6 when [starCount] is 0, leaving
///   the icon genuinely empty.
/// - `stars_idle_loop` — a seamless twinkle loop on the settled stars (or
///   nothing, for the 0-star case). This is the permanent "ready" resting
///   look (not a bolt anymore).
///
/// Entering `searching_star_loop` is always a jump to that segment's exact
/// start frame, so it never needs masking (the 6 survivors are authored to
/// look continuous there, same as the phase-1 wiggle). Leaving it, though,
/// the search star's position is arbitrary at the moment call #2 resolves,
/// so that transition is masked with a brief opacity dip (see
/// [_crossfadeJump]) rather than relying on a seamless hard cut.
class LottieBoltIcon extends StatefulWidget {
  const LottieBoltIcon({
    super.key,
    required this.state,
    this.size = 24,
    this.starCount = 4,
  });

  final BoltState state;
  final double size;

  /// How many stars the `ready` state should settle into (0, 2, 3, 4, or
  /// 5 -- 1 is never a valid value), standing in for "how many results
  /// came back" from call #2. Selects which of the five pre-baked
  /// composition variants is loaded.
  final int starCount;

  @override
  State<LottieBoltIcon> createState() => _LottieBoltIconState();
}

class _LottieBoltIconState extends State<LottieBoltIcon>
    with TickerProviderStateMixin {
  static final Color _idleColor = Colors.purple[600]!;
  static const _crossfadeDuration = Duration(milliseconds: 220);
  static const _dipDuration = Duration(milliseconds: 130);

  static const _markerIdleToBroken = 'idle_to_broken';
  static const _markerBrokenLoop = 'broken_loop';
  static const _markerSearchingStarLoop = 'searching_star_loop';
  static const _markerBrokenToStars = 'broken_to_stars';
  static const _markerStarsIdleLoop = 'stars_idle_loop';

  late final AnimationController _controller;
  LottieComposition? _composition;

  /// Bumped every time we start (or deliberately skip) a new segment
  /// transition, so a stale `await` from a superseded transition knows to
  /// bail out instead of clobbering whatever should be playing now.
  int _playToken = 0;

  /// Briefly true while masking an internal "cut" (e.g. jumping into/out of
  /// the search-star loop, whose position is arbitrary when interrupted).
  bool _dipped = false;

  String get _asset =>
      'assets/animations/bolt_shatter_stars_${widget.starCount}.json';

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this);
  }

  Marker? _marker(String name) => _composition?.getMarker(name);

  // The `lottie` package's LottieComposition internally shaves a hair off
  // its parsed out-point (see its composition parser subtracting 0.01 from
  // the raw frame count) when computing total duration, but our markers'
  // start/end fractions are derived from the *raw* frame numbers baked by
  // the generator script. For any marker whose end frame lands exactly on
  // the composition's last frame (true for `stars_idle_loop`, the final
  // segment), that mismatch can push `marker.end` a hair past 1.0 --
  // clamping here keeps `AnimationController.repeat`'s `max <= upperBound`
  // assertion safe regardless of that internal rounding.
  double _clampProgress(double value) => value.clamp(0.0, 1.0);

  Duration _segmentDuration(Marker marker) {
    return _composition!.duration *
        (_clampProgress(marker.end) - _clampProgress(marker.start));
  }

  void _repeatMarker(Marker marker) {
    final start = _clampProgress(marker.start);
    final end = _clampProgress(marker.end);
    _controller.value = start;
    _controller.repeat(
      min: start,
      max: end,
      period: _segmentDuration(marker),
    );
  }

  /// Fades the Lottie layer out, runs [jump] while invisible, then fades it
  /// back in -- used to mask any "cut" between two unrelated playback
  /// positions so no discontinuity is ever visibly rendered.
  Future<void> _crossfadeJump(int token, VoidCallback jump) async {
    setState(() => _dipped = true);
    await Future.delayed(_dipDuration);
    if (token != _playToken || !mounted) return;
    jump();
    setState(() => _dipped = false);
  }

  void _onLoaded(LottieComposition composition) {
    _composition = composition;
    _controller.duration = composition.duration;
    // Land directly on whatever the *current* state calls for. If a state
    // change raced the (near-instant, bundled-asset) composition load, its
    // intro transition is skipped in favor of snapping straight to the loop
    // it leads into — see caveats in the widget doc comment above.
    _snapToCurrentState();
  }

  /// Jumps straight to the resting frame/loop for [widget.state], with no
  /// transition animation. Used on first load and as a safe fallback.
  void _snapToCurrentState() {
    if (_composition == null) return;
    _controller.stop();
    _dipped = false;

    switch (widget.state) {
      case BoltState.idle:
        _controller.value = 0;
        break;
      case BoltState.loadingPrimary:
        final loop = _marker(_markerBrokenLoop);
        loop == null ? _controller.value = 0 : _repeatMarker(loop);
        break;
      case BoltState.loadingSecondary:
        final loop = _marker(_markerSearchingStarLoop);
        loop == null ? _controller.value = 0 : _repeatMarker(loop);
        break;
      case BoltState.ready:
        final idleLoop = _marker(_markerStarsIdleLoop);
        idleLoop == null ? _controller.value = 1 : _repeatMarker(idleLoop);
        break;
    }
  }

  /// Phase 1: plays the break-apart once, then falls into the endless
  /// "waiting" loop — unless the state has already moved on by the time the
  /// break-apart finishes (call #1 resolved very fast).
  Future<void> _playBreakThenLoop(int token) async {
    final breakSeg = _marker(_markerIdleToBroken);
    final loop = _marker(_markerBrokenLoop);
    if (breakSeg == null || loop == null) return;

    _controller.stop();
    _controller.value = _clampProgress(breakSeg.start);
    await _controller.animateTo(
      _clampProgress(breakSeg.end),
      duration: _segmentDuration(breakSeg),
      curve: Curves.linear,
    );
    if (token != _playToken || !mounted) return;

    if (widget.state == BoltState.loadingPrimary) {
      _repeatMarker(loop);
    } else {
      _snapToCurrentState();
    }
  }

  /// Phase 2 entry: 10 of the 16 fragments fade away (baked into the
  /// segment's own keyframes right at its start frame) and a single star
  /// starts wandering among the 6 that remain. No dip is needed here --
  /// we always jump straight to this segment's exact start frame, and the
  /// 6 survivors are authored to hold their phase-1 look continuously
  /// across that boundary (same reasoning as [_playBreakThenLoop] falling
  /// into `broken_loop`).
  void _enterSearchLoop(int token) {
    final loop = _marker(_markerSearchingStarLoop);
    if (loop == null) return;

    _controller.stop();
    _repeatMarker(loop);
  }

  /// Phase 3: the wandering star hides, the fragments reappear at their
  /// held "broken" pose (masked with a crossfade dip, since the star could
  /// be anywhere along its loop when call #2 resolves), then the bloom
  /// plays once, settling into the stars' idle twinkle loop.
  Future<void> _playBloomThenIdle(int token) async {
    final bloom = _marker(_markerBrokenToStars);
    final idleLoop = _marker(_markerStarsIdleLoop);
    if (bloom == null || idleLoop == null) return;

    await _crossfadeJump(token, () {
      _controller.stop();
      _controller.value = _clampProgress(bloom.start);
    });
    if (token != _playToken || !mounted) return;

    await _controller.animateTo(
      _clampProgress(bloom.end),
      duration: _segmentDuration(bloom),
      curve: Curves.linear,
    );
    if (token != _playToken || !mounted) return;

    if (widget.state == BoltState.ready) {
      _repeatMarker(idleLoop);
    } else {
      _snapToCurrentState();
    }
  }

  @override
  void didUpdateWidget(covariant LottieBoltIcon oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.state == widget.state) {
      return;
    }
    // No composition yet: `_onLoaded` will snap to whatever state we're in
    // by the time it fires.
    if (_composition == null) return;

    switch (widget.state) {
      case BoltState.idle:
        _playToken++;
        _snapToCurrentState();
        break;
      case BoltState.loadingPrimary:
        _playBreakThenLoop(++_playToken);
        break;
      case BoltState.loadingSecondary:
        _playToken++;
        _enterSearchLoop(_playToken);
        break;
      case BoltState.ready:
        _playBloomThenIdle(++_playToken);
        break;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // +24 gives a ~48dp tap target (Material's recommended minimum) around
    // the [widget.size] glyph, and headroom for the Lottie composition's
    // shatter/bloom effects -- constant across every state, so this box
    // never changes size/position as the icon animates or transitions.
    final diameter = widget.size + 24;
    final isIdle = widget.state == BoltState.idle;
    return SizedBox(
      width: diameter,
      height: diameter,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // idle: static purple bolt, pixel-identical to the original icon.
          AnimatedOpacity(
            opacity: isIdle ? 1 : 0,
            duration: _crossfadeDuration,
            child: Icon(Icons.electric_bolt, color: _idleColor, size: widget.size),
          ),
          // loadingPrimary / loadingSecondary / ready: the shatter -> hold
          // -> search -> bloom -> stars composition, segment-driven by
          // _controller, with an extra opacity dip for internal cuts.
          AnimatedOpacity(
            opacity: isIdle ? 0 : 1,
            duration: _crossfadeDuration,
            child: AnimatedOpacity(
              opacity: _dipped ? 0 : 1,
              duration: _dipDuration,
              child: SizedBox(
                width: diameter,
                height: diameter,
                // Keyed by asset path so switching star-count variants (only
                // ever between fresh AI-fill cycles, never mid-animation)
                // reloads cleanly rather than reusing stale frame data.
                child: Lottie.asset(
                  _asset,
                  key: ValueKey(_asset),
                  controller: _controller,
                  fit: BoxFit.contain,
                  onLoaded: _onLoaded,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
