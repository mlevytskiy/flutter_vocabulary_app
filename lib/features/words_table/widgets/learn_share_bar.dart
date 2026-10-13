import 'package:flutter/material.dart';

/// The Words screen's top bar: the back arrow on the left, the title in the
/// middle of the screen, Learn centred between the arrow and the title, Share
/// centred between the title and the right edge.
///
/// The layout is chosen by measuring the width actually available at the
/// current text scale (no fixed breakpoints): normal, compact (smaller padding,
/// labels kept) or icon-only (a Tooltip names each button).
class LearnShareBar extends StatelessWidget implements PreferredSizeWidget {
  const LearnShareBar({
    super.key,
    required this.title,
    required this.onLearn,
    required this.onShare,
    this.isSharing = false,
  });

  final String title;
  final VoidCallback onLearn;

  /// Null disables Share (as today while a publish is in flight).
  final VoidCallback? onShare;

  /// Shows Share's progress spinner instead of its icon.
  final bool isSharing;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  static const double _leadingWidth = 56.0; // AppBar's back arrow
  static const double _iconLabelPadding = 16.0 + 24.0; // ElevatedButton.icon
  static const double _compactButtonPadding = 8.0 + 8.0;
  static const double _iconSize = 18.0;
  static const double _iconGap = 8.0;
  static const double _iconOnlySize = 48.0;

  /// The full-size button's own height, so every layout is as tall as Share
  /// at full size. The tap target is still padded to 48 by Material.
  static const double _buttonHeight = 40.0;
  static const double _margin = 8.0; // measuring slack

  double _text(BuildContext context, String s, TextStyle? style) {
    final painter = TextPainter(
      text: TextSpan(text: s, style: style),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 1,
    )..layout();
    return painter.width;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final canPop = Navigator.maybeOf(context)?.canPop() ?? false;
    return LayoutBuilder(builder: (context, constraints) {
      final titleStyle =
          AppBarTheme.of(context).titleTextStyle ?? theme.textTheme.titleLarge;
      final labelStyle = theme.textTheme.labelLarge;
      final words = _text(context, title, titleStyle);
      final learn = _text(context, 'Learn', labelStyle);
      final share = _text(context, 'Share', labelStyle);
      // Material's own padding shrinks as the text scale grows, so using the
      // 100 % padding here is on the safe side.
      double button(double label, double padding) =>
          padding + _iconSize + _iconGap + label;
      // Arrow | Learn's space | Words in the middle of the screen | Share's
      // space up to the right edge: each button has to fit in its space.
      final side = canPop ? _leadingWidth : 0.0;
      final right = (constraints.maxWidth - words - _margin) / 2;
      final left = right - side;
      // Each button picks its own layout, so Share keeps the full padding in
      // its wider space even when Learn has to shrink.
      _Layout pick(double label, double space) {
        if (button(label, _iconLabelPadding) <= space) return _Layout.normal;
        if (button(label, _compactButtonPadding) <= space) {
          return _Layout.compact;
        }
        return _Layout.iconOnly;
      }

      return AppBar(
        centerTitle: true,
        titleSpacing: 0,
        title: Row(
          children: [
            SizedBox(
              width: left < 0 ? 0 : left,
              child: Center(
                child: _button(context, pick(learn, left), 'Learn',
                    const Icon(Icons.school), onLearn),
              ),
            ),
            Expanded(child: Center(child: Text(title, softWrap: false))),
            SizedBox(
              width: right,
              child: Center(
                child: _button(
                    context, pick(share, right), 'Share', _shareIcon, onShare),
              ),
            ),
          ],
        ),
        backgroundColor: theme.colorScheme.inversePrimary,
      );
    });
  }

  Widget get _shareIcon => isSharing
      ? const SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(strokeWidth: 2),
        )
      : const Icon(Icons.share);

  Widget _button(BuildContext context, _Layout layout, String name, Widget icon,
      VoidCallback? onPressed) {
    final style = ElevatedButton.styleFrom(
      backgroundColor: Colors.white,
      foregroundColor: Theme.of(context).colorScheme.primary,
    );
    switch (layout) {
      case _Layout.iconOnly:
        return Tooltip(
          message: name,
          child: ElevatedButton(
            onPressed: onPressed,
            style: style.copyWith(
              minimumSize: const WidgetStatePropertyAll(
                  Size(_iconOnlySize, _buttonHeight)),
              padding: const WidgetStatePropertyAll(EdgeInsets.zero),
            ),
            child: icon,
          ),
        );
      case _Layout.compact:
        return ElevatedButton.icon(
          onPressed: onPressed,
          icon: icon,
          label: Text(name),
          style: style.copyWith(
            padding: const WidgetStatePropertyAll(
              EdgeInsets.symmetric(horizontal: 8),
            ),
            minimumSize: const WidgetStatePropertyAll(Size(48, _buttonHeight)),
          ),
        );
      case _Layout.normal:
        return ElevatedButton.icon(
          onPressed: onPressed,
          icon: icon,
          label: Text(name),
          style: style,
        );
    }
  }
}

enum _Layout { normal, compact, iconOnly }
