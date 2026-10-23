import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

/// The "Learn with" drop-down beside Learn on the Words top bar (learn-redesign
/// AC-04, SCR-01): a person icon with a small arrow, 48 px wide in every bar
/// layout. Only "Learn alone" works today; teacher and friend are disabled with
/// "Soon" (ADR-0010).
class CompanionButton extends StatelessWidget {
  const CompanionButton({super.key});

  /// The tap target's width, which the bar counts on.
  static const double width = 48.0;

  @override
  Widget build(BuildContext context) {
    final decor = AppDecor.of(context);
    final color = decor.onBarButtonOf(context);
    return PopupMenuButton<String>(
      tooltip: 'Learn with',
      padding: EdgeInsets.zero,
      // Selecting "alone" changes nothing: the sheet is for learning alone.
      onSelected: (_) {},
      itemBuilder: (context) => [
        const PopupMenuItem<String>(
          value: 'alone',
          child: Row(children: [
            Icon(Icons.check, size: 20),
            SizedBox(width: 12),
            Text('Learn alone'),
          ]),
        ),
        const PopupMenuItem<String>(
          value: 'teacher',
          enabled: false,
          child: _SoonRow('With teacher'),
        ),
        const PopupMenuItem<String>(
          value: 'friend',
          enabled: false,
          child: _SoonRow('With friend'),
        ),
      ],
      child: Container(
        width: width,
        height: 40,
        decoration: BoxDecoration(
          color: decor.barButton,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.person, size: 20, color: color),
            Icon(Icons.arrow_drop_down, size: 18, color: color),
          ],
        ),
      ),
    );
  }
}

class _SoonRow extends StatelessWidget {
  const _SoonRow(this.label);
  final String label;

  @override
  Widget build(BuildContext context) => Row(children: [
        const SizedBox(width: 32),
        Expanded(child: Text(label)),
        const Text('Soon'),
      ]);
}
