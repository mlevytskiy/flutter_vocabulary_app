import 'package:flutter/material.dart';

/// The recycle-bin target at the bottom of a folder while dragging (SCR-04
/// dragging, AC-14). [highlighted] while a dragged item hovers over it;
/// [wrapper] lets the screen wrap the zone, e.g. in a `DragTarget` (T18).
class BinDropZone extends StatelessWidget {
  const BinDropZone({super.key, this.highlighted = false, this.wrapper});

  final bool highlighted;
  final Widget Function(BuildContext context, Widget zone)? wrapper;

  static const label = 'Drop here to delete';

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fg = highlighted ? scheme.onErrorContainer : scheme.onSurfaceVariant;
    final zone = AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      margin: const EdgeInsets.all(8),
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: highlighted ? scheme.errorContainer : scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: highlighted ? scheme.error : scheme.outline),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.delete_outline, color: fg),
          const SizedBox(width: 8),
          Text(label, style: TextStyle(fontSize: 16, color: fg)),
        ],
      ),
    );
    return wrapper?.call(context, zone) ?? zone;
  }
}
