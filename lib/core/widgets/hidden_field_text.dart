import 'package:flutter/foundation.dart' show setEquals;
import 'package:flutter/widgets.dart';

/// Hides the typed text of the fields whose controllers are in
/// [controllers], below it: their glyphs are drawn transparent while the
/// field keeps its layout, border and label. A word row uses it while its
/// text flies to the row's one line and back (photo-panel-glass), so the
/// text is never drawn twice. Without one above it, a field is as before.
class HiddenFieldText extends InheritedWidget {
  const HiddenFieldText({
    super.key,
    required this.controllers,
    required super.child,
  });

  final Set<TextEditingController> controllers;

  /// [style] for the field of [controller]: transparent while hidden.
  static TextStyle styleFor(
      BuildContext context, TextEditingController controller, TextStyle style) {
    final hidden = context
            .dependOnInheritedWidgetOfExactType<HiddenFieldText>()
            ?.controllers
            .contains(controller) ??
        false;
    return hidden ? style.copyWith(color: const Color(0x00000000)) : style;
  }

  @override
  bool updateShouldNotify(HiddenFieldText oldWidget) =>
      !setEquals(oldWidget.controllers, controllers);
}
