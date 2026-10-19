import 'package:popup_menu_2/popup_menu.dart';

class MyCustomPopupMenuController extends CustomPopupMenuController {
  initialize() {
    print("CustomPopupMenuController, ${hashCode} initialize");
  }

  /// Displays the popup menu.
  void showMenu() {
    print("CustomPopupMenuController, ${hashCode} showMenu");
    super.showMenu();
  }

  /// Hides the popup menu.
  void hideMenu() {
    print("CustomPopupMenuController, ${hashCode} hideMenu");
    super.hideMenu();
  }

  /// Toggles the visibility of the popup menu.
  void toggleMenu() {
    print("CustomPopupMenuController, ${hashCode} toggleMenu");
    super.toggleMenu();
  }
}
