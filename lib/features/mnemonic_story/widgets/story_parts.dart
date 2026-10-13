import 'package:flutter/material.dart';

// The story screen's progress label, messages and buttons, cut from it so the
// dialogue screen shows a scene picture's progress and failures the same way
// (get-words-from-subtitles-improvment SCR-07).

/// A column of messages and buttons in the middle of the screen.
class StoryPlain extends StatelessWidget {
  const StoryPlain(this.children, {super.key});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(mainAxisSize: MainAxisSize.min, children: children),
        ),
      );
}

class StoryLabel extends StatelessWidget {
  const StoryLabel(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2)),
          const SizedBox(width: 12),
          Text(text, style: Theme.of(context).textTheme.bodyMedium),
        ]),
      );
}

class StoryMessage extends StatelessWidget {
  const StoryMessage(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(text,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium),
      );
}

class StoryAction extends StatelessWidget {
  const StoryAction(this.label, this.onPressed, {super.key});
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: ElevatedButton(onPressed: onPressed, child: Text(label)),
      );
}
