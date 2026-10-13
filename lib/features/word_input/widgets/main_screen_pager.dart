import 'package:flutter/material.dart';

/// The main screen when the current session has film dialogues
/// (get-words-from-subtitles-improvment SCR-01): page 1 is [first], today's
/// screen as it is, then one page per dialogue, with a small page indicator.
/// The page controller and the current page stay in the screen's State.
class MainScreenPager extends StatelessWidget {
  const MainScreenPager({
    super.key,
    required this.controller,
    required this.page,
    required this.onPageChanged,
    required this.first,
    required this.pages,
  });

  final PageController controller;
  final int page;
  final ValueChanged<int> onPageChanged;
  final Widget first;
  final List<Widget> pages;

  @override
  Widget build(BuildContext context) {
    final count = pages.length + 1;
    final current = page.clamp(0, count - 1);
    final colors = Theme.of(context).colorScheme;
    return Stack(
      children: [
        PageView(
          controller: controller,
          onPageChanged: onPageChanged,
          children: [first, ...pages],
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 8,
          child: IgnorePointer(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < count; i++)
                  Container(
                    width: 6,
                    height: 6,
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: i == current
                          ? colors.primary
                          : colors.outlineVariant,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
