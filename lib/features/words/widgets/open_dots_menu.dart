import 'package:flutter/widgets.dart';
import 'package:popup_menu_2/popup_menu_2.dart';

/// Opens a dots popup once the keyboard is out of the way.
///
/// `popup_menu_2` measures the anchor's position once, when the menu is shown,
/// and never re-measures it. Tapping the dots drops the keyboard ([onOpen]),
/// and as it slides away the list grows and a row below the top moves down --
/// so a menu shown in the same tap would stay pinned to where the dots used to
/// be. With the keyboard up we therefore wait for it to finish closing (plus
/// one frame, so the list has been laid out at its new size) and only then
/// show the menu. With the keyboard already down the menu opens at once, as
/// before.
void openDotsMenu(
  BuildContext context,
  CustomPopupMenuController controller,
  VoidCallback onOpen,
) {
  if (controller.menuIsShowing) return;
  final keyboardUp = View.of(context).viewInsets.bottom > 0;
  onOpen();
  if (!keyboardUp) {
    controller.showMenu();
    return;
  }

  // Safety net: if the inset never reaches zero (e.g. a floating keyboard),
  // open anyway rather than swallow the tap.
  Duration? start;
  var settledFrames = 0;
  void check(Duration frameTime) {
    if (!context.mounted || controller.menuIsShowing) return;
    start ??= frameTime;
    final keyboardGone = View.of(context).viewInsets.bottom == 0;
    settledFrames = keyboardGone ? settledFrames + 1 : 0;
    final timedOut = frameTime - start! > const Duration(milliseconds: 800);
    if (settledFrames >= 2 || timedOut) {
      controller.showMenu();
      return;
    }
    WidgetsBinding.instance
      ..addPostFrameCallback(check)
      ..scheduleFrame();
  }

  WidgetsBinding.instance
    ..addPostFrameCallback(check)
    ..scheduleFrame();
}
