import 'package:flutter/material.dart';

/// The Words screen's top bar: back arrow, Learn, the title, Share.
///
/// The layout is chosen by measuring the width actually available at the
/// current text scale (no fixed breakpoints): normal (today's padding), compact
/// (smaller padding, labels kept) or icon-only (a Tooltip names each button).
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

  static const double _normalPad = 16.0; // Share's Padding(right: 16) today
  static const double _compactPad = 4.0;
  static const double _gap = 8.0;
  static const double _leadingWidth = 56.0; // AppBar's back arrow
  static const double _titleSpacing = NavigationToolbar.kMiddleSpacing;
  static const double _iconLabelPadding = 16.0 + 24.0; // ElevatedButton.icon
  static const double _compactButtonPadding = 8.0 + 8.0;
  static const double _iconSize = 18.0;
  static const double _iconGap = 8.0;
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
      double need(double pad, double spacing, double buttonPadding) =>
          (canPop ? _leadingWidth : 0) +
          spacing +
          button(learn, buttonPadding) +
          _gap +
          words +
          button(share, buttonPadding) +
          pad +
          _margin;
      final width = constraints.maxWidth;
      final _Layout layout;
      if (need(_normalPad, _titleSpacing, _iconLabelPadding) <= width) {
        layout = _Layout.normal;
      } else if (need(_compactPad, _compactPad, _compactButtonPadding) <=
          width) {
        layout = _Layout.compact;
      } else {
        layout = _Layout.iconOnly;
      }
      return _build(context, layout);
    });
  }

  Widget _build(BuildContext context, _Layout layout) {
    final primary = Theme.of(context).colorScheme.primary;
    final style = ElevatedButton.styleFrom(
      backgroundColor: Colors.white,
      foregroundColor: primary,
    );
    final compact = layout != _Layout.normal;
    final Widget learn;
    final Widget share;
    final shareIcon = isSharing
        ? const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : const Icon(Icons.share);
    if (layout == _Layout.iconOnly) {
      final iconStyle = style.copyWith(
        minimumSize: const WidgetStatePropertyAll(Size(48, 48)),
        padding: const WidgetStatePropertyAll(EdgeInsets.zero),
      );
      learn = Tooltip(
        message: 'Learn',
        child: ElevatedButton(
          onPressed: onLearn,
          style: iconStyle,
          child: const Icon(Icons.school),
        ),
      );
      share = Tooltip(
        message: 'Share',
        child: ElevatedButton(
          onPressed: onShare,
          style: iconStyle,
          child: shareIcon,
        ),
      );
    } else {
      final labelStyle = compact
          ? style.copyWith(
              padding: const WidgetStatePropertyAll(
                EdgeInsets.symmetric(horizontal: 8),
              ),
              minimumSize: const WidgetStatePropertyAll(Size(48, 48)),
            )
          : style;
      learn = ElevatedButton.icon(
        onPressed: onLearn,
        icon: const Icon(Icons.school),
        label: const Text('Learn'),
        style: labelStyle,
      );
      share = ElevatedButton.icon(
        onPressed: onShare,
        icon: shareIcon,
        label: const Text('Share'),
        style: labelStyle,
      );
    }
    return AppBar(
      titleSpacing: compact ? _compactPad : null,
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          learn,
          const SizedBox(width: _gap),
          Text(title, softWrap: false),
        ],
      ),
      backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      actions: [
        Padding(
          padding: EdgeInsets.only(right: compact ? _compactPad : _normalPad),
          child: share,
        ),
      ],
    );
  }
}

enum _Layout { normal, compact, iconOnly }
