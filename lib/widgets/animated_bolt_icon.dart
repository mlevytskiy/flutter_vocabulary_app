import 'package:flutter/material.dart';

/// The states the AI auto-fill bolt icon can be in.
///
/// There are two chained async calls behind a translation: the real
/// translate call, followed by a (currently mocked) "additional info" call.
/// [loadingPrimary]/[loadingSecondary] let the UI distinguish between them
/// even though this particular (non-Lottie) widget renders them the same way
/// — see `lottie_bolt_icon.dart` for the richer multi-phase treatment.
enum BoltState {
  /// No translation yet — tap to auto-fill.
  idle,

  /// Call #1 (translate) is in flight.
  loadingPrimary,

  /// Call #2 (additional info) is in flight.
  loadingSecondary,

  /// Both calls finished — tap to see alternatives.
  ready,
}

/// A lightning-bolt icon that animates between [BoltState]s instead of
/// instantly swapping color/widget like a plain conditional would.
///
/// - idle -> loading: the bolt starts pulsing with a spinning "charging" ring.
/// - loading -> ready: the bolt "pops" (springy scale bounce) while its color
///   morphs smoothly from purple to amber, signalling the translation landed.
/// - ready -> idle: a gentler pop back to purple (e.g. translation cleared).
class AnimatedBoltIcon extends StatefulWidget {
  const AnimatedBoltIcon({
    super.key,
    required this.state,
    this.size = 28,
  });

  final BoltState state;
  final double size;

  @override
  State<AnimatedBoltIcon> createState() => _AnimatedBoltIconState();
}

class _AnimatedBoltIconState extends State<AnimatedBoltIcon>
    with TickerProviderStateMixin {
  static final Color _idleColor = Colors.purple[600]!;
  static final Color _readyColor = Colors.amber[600]!;

  late final AnimationController _loadingController;
  late final AnimationController _morphController;

  late Animation<double> _pulseScale;
  late Animation<double> _popScale;
  late Animation<Color?> _colorAnimation;

  late Color _currentColor;

  @override
  void initState() {
    super.initState();
    _currentColor = _colorForState(widget.state);

    _loadingController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );
    _pulseScale = TweenSequence<double>([
      TweenSequenceItem(
        weight: 50,
        tween: Tween(begin: 0.88, end: 1.1)
            .chain(CurveTween(curve: Curves.easeInOut)),
      ),
      TweenSequenceItem(
        weight: 50,
        tween: Tween(begin: 1.1, end: 0.88)
            .chain(CurveTween(curve: Curves.easeInOut)),
      ),
    ]).animate(_loadingController);

    _morphController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 550),
    );
    _popScale = _buildPopScaleAnimation();
    _colorAnimation = ColorTween(begin: _currentColor, end: _currentColor)
        .animate(_morphController);

    if (_isLoading(widget.state)) {
      _loadingController.repeat();
    }
  }

  static bool _isLoading(BoltState state) =>
      state == BoltState.loadingPrimary || state == BoltState.loadingSecondary;

  Animation<double> _buildPopScaleAnimation() {
    return TweenSequence<double>([
      TweenSequenceItem(
        weight: 35,
        tween: Tween(begin: 1.0, end: 1.35)
            .chain(CurveTween(curve: Curves.easeOut)),
      ),
      TweenSequenceItem(
        weight: 30,
        tween: Tween(begin: 1.35, end: 0.9)
            .chain(CurveTween(curve: Curves.easeInOut)),
      ),
      TweenSequenceItem(
        weight: 35,
        tween: Tween(begin: 0.9, end: 1.0)
            .chain(CurveTween(curve: Curves.easeOut)),
      ),
    ]).animate(_morphController);
  }

  Color _colorForState(BoltState state) {
    switch (state) {
      case BoltState.ready:
        return _readyColor;
      case BoltState.idle:
      case BoltState.loadingPrimary:
      case BoltState.loadingSecondary:
        return _idleColor;
    }
  }

  @override
  void didUpdateWidget(covariant AnimatedBoltIcon oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.state == widget.state) return;

    final wasLoading = _isLoading(oldWidget.state);
    final isLoading = _isLoading(widget.state);

    if (isLoading && !wasLoading) {
      _loadingController.repeat();
    } else if (!isLoading && wasLoading) {
      _loadingController.stop();
      _loadingController.value = 0;
    }

    final targetColor = _colorForState(widget.state);
    if (targetColor != _currentColor) {
      _colorAnimation = ColorTween(begin: _currentColor, end: targetColor)
          .animate(CurvedAnimation(
        parent: _morphController,
        curve: Curves.easeInOut,
      ));
      _currentColor = targetColor;
      _morphController.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _loadingController.dispose();
    _morphController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final diameter = widget.size + 24;
    return AnimatedBuilder(
      animation: Listenable.merge([_loadingController, _morphController]),
      builder: (context, _) {
        final color = _colorAnimation.value ?? _currentColor;
        final scale =
            _isLoading(widget.state) ? _pulseScale.value : _popScale.value;

        return SizedBox(
          width: diameter,
          height: diameter,
          child: Center(
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (_isLoading(widget.state))
                  SizedBox(
                    width: widget.size + 14,
                    height: widget.size + 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        color.withValues(alpha: 0.55),
                      ),
                    ),
                  ),
                Transform.scale(
                  scale: scale,
                  child: Icon(
                    Icons.electric_bolt,
                    color: color,
                    size: widget.size,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
