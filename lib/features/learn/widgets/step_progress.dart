import 'package:flutter/material.dart';

/// The learn page's step indicator: Step 1 → Step 2 → Step 3, as numbered
/// circles joined by lines, each with its name underneath.
///
/// Steps up to the current one are filled with the primary colour (and so is
/// the line leading to them); the rest are outlined. Tapping a step calls
/// [onTap] with its index.
class StepProgress extends StatelessWidget {
  const StepProgress({
    super.key,
    required this.labels,
    required this.current,
    this.onTap,
  });

  final List<String> labels;
  final int current;
  final ValueChanged<int>? onTap;

  static const double _dot = 28.0;
  static const _duration = Duration(milliseconds: 200);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < labels.length; i++) ...[
          if (i > 0)
            Expanded(
              child: Padding(
                // Centred on the circles, with a little air either side.
                padding: const EdgeInsets.only(top: _dot / 2 - 1),
                child: AnimatedContainer(
                  duration: _duration,
                  height: 2,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  color: i <= current ? scheme.primary : scheme.outlineVariant,
                ),
              ),
            ),
          Semantics(
            button: onTap != null,
            selected: i == current,
            child: InkWell(
              onTap: onTap == null ? null : () => onTap!(i),
              customBorder: const StadiumBorder(),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedContainer(
                    duration: _duration,
                    width: _dot,
                    height: _dot,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: i <= current ? scheme.primary : null,
                      border: Border.all(
                        color: i <= current
                            ? scheme.primary
                            : scheme.outlineVariant,
                        width: 2,
                      ),
                    ),
                    child: Text(
                      '${i + 1}',
                      style: textTheme.labelLarge?.copyWith(
                        color: i <= current
                            ? scheme.onPrimary
                            : scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    labels[i],
                    style: textTheme.labelMedium?.copyWith(
                      color: i == current
                          ? scheme.primary
                          : scheme.onSurfaceVariant,
                      fontWeight: i == current ? FontWeight.bold : null,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}
