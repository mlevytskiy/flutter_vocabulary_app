import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../router/routes.dart';

/// The side menu's screens (navigation, owner 2026-10-18), in menu order.
enum AppMenuItem { collections, words, appSettings }

/// The side menu, the same on every screen it opens: Collections first (the
/// start screen), then Words, then App settings. Each opens with `go`, so the
/// screen is alone on its branch and its top bar shows the menu button.
///
/// The menu screens are kept alive in one shell (`MenuShellRoute`), each with
/// its own drawer. A tap lets this drawer slide shut over its own screen and
/// only then shows the other one, so the menu closes smoothly and no new
/// screen is pushed on top.
class AppDrawer extends StatefulWidget {
  const AppDrawer({super.key, required this.current, this.wrap});

  /// The screen showing this drawer; its row is selected and only closes.
  final AppMenuItem current;

  /// Wraps the menu's list, e.g. the Words screen's StillBodyWhileMounted.
  final Widget Function(Widget list)? wrap;

  static const collectionsKey = Key('drawer-collections');
  static const wordsKey = Key('drawer-words');
  static const appSettingsKey = Key('drawer-app-settings');

  @override
  State<AppDrawer> createState() => _AppDrawerState();
}

class _AppDrawerState extends State<AppDrawer> {
  /// The screen to show once the drawer has closed.
  String? _pendingLocation;
  GoRouter? _router;

  /// The Scaffold drops the drawer from the tree once it is fully closed.
  @override
  void dispose() {
    final location = _pendingLocation;
    final router = _router;
    if (location != null && router != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => router.go(location));
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Widget item(AppMenuItem item, Key key, IconData icon, String title,
            String location) =>
        ListTile(
          key: key,
          leading: Icon(icon),
          title: Text(title),
          selected: item == widget.current,
          onTap: () {
            if (item != widget.current) {
              _pendingLocation = location;
              _router = GoRouter.of(context);
            }
            Navigator.pop(context);
          },
        );
    final list = ListView(
      padding: EdgeInsets.zero,
      children: [
        DrawerHeader(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.inversePrimary,
          ),
          child: const Text(
            'Меню',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
        ),
        item(AppMenuItem.collections, AppDrawer.collectionsKey,
            Icons.folder_outlined, 'Collections',
            const CollectionsRoute().location),
        item(AppMenuItem.words, AppDrawer.wordsKey, Icons.edit_note, 'Words',
            const WordsRoute().location),
        item(AppMenuItem.appSettings, AppDrawer.appSettingsKey,
            Icons.palette_outlined, 'App settings',
            const AppSettingsRoute().location),
      ],
    );
    return Drawer(child: widget.wrap?.call(list) ?? list);
  }
}

/// The drawer for a screen the menu may open: there only while the screen is
/// the root of the stack, so a pushed one (a tag tap opening Collections)
/// keeps its Back button.
Widget? appDrawerIfRoot(BuildContext context, AppMenuItem current) =>
    _hasScreenBelow(context) ? null : AppDrawer(current: current);

/// A screen is under this one. Not `ModalRoute.canPop`: that turns true
/// while the drawer is open (its local history entry) and would take the
/// drawer away as it opens.
bool _hasScreenBelow(BuildContext context) =>
    ModalRoute.of(context)?.impliesAppBarDismissal ?? false;

/// Back on a menu screen other than Collections goes to Collections, the
/// start screen, rather than leaving the app. Goes inside the Scaffold (its
/// body), so Back with the drawer open only closes the drawer.
class BackToCollections extends StatelessWidget {
  const BackToCollections({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => PopScope(
        canPop: _hasScreenBelow(context),
        onPopInvokedWithResult: (didPop, _) {
          if (didPop) return;
          final scaffold = Scaffold.maybeOf(context);
          if (scaffold != null && scaffold.isDrawerOpen) {
            scaffold.closeDrawer();
          } else {
            const CollectionsRoute().go(context);
          }
        },
        child: child,
      );
}
