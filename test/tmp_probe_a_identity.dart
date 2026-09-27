import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:popup_menu_2/popup_menu_2.dart';
import 'package:flutter_vocabulary_app/features/word_input/widgets/translation_dots_button.dart';

/// PROBE A -- is the failure about the *identity* of the controller the widget
/// holds, or about anything at all happening to the map before the tap?
///
/// Difference from the earlier probe: the row's widget is handed the map
/// controller through `putIfAbsent` in a WIDGET (so the package binds that
/// exact instance in initState), and the wipe happens while the list is
/// off-screen via an ancestor rebuild that does NOT recreate the row element.
class Host extends StatefulWidget {
  const Host({super.key, required this.rows});
  final int rows;
  @override
  State<Host> createState() => HostState();
}

class HostState extends State<Host> {
  final Map<int, CustomPopupMenuController> controllers = {};
  bool showList = true;
  int tick = 0;

  void wipeOnlyMap() {
    setState(() {
      // The map is thrown away and rebuilt, the widget tree is NOT.
      controllers.removeWhere((k, v) => true);
      tick++;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!showList) return const SizedBox();
    return Column(
      children: [
        Text('tick $tick'),
        Expanded(
          child: ListView.builder(
            itemCount: widget.rows,
            padding: const EdgeInsets.all(16),
            itemBuilder: (context, i) => SizedBox(
              height: 60,
              child: Row(
                children: [
                  const Expanded(child: SizedBox()),
                  TranslationDotsButton(
                    key: ValueKey('dots_$i'),
                    controller: controllers.putIfAbsent(
                        i, () => CustomPopupMenuController()),
                    options: null,
                    onSelectTranslation: (_) {},
                    onLoadTranslations: () async => null,
                    onOpen: () {},
                    onClose: () => controllers[i]?.hideMenu(),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

bool menuVisible() => find
    .byWidgetPredicate((w) => w is Material && w.color == Colors.black87)
    .evaluate()
    .isNotEmpty;

void main() {
  testWidgets('A: wipe the map only, then tap row 0 close', (tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final k = GlobalKey<HostState>();
    await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: Host(key: k, rows: 2))));
    await tester.pumpAndSettle();

    final boundAtBuild = k.currentState!.controllers[0]!;
    debugPrint('A: controller bound at first build = ${boundAtBuild.hashCode}');

    k.currentState!.wipeOnlyMap();
    await tester.pumpAndSettle();

    final nowInMap = k.currentState!.controllers[0]!;
    debugPrint('A: controller in map after wipe   = ${nowInMap.hashCode}');
    debugPrint('A: identity changed              = ${!identical(boundAtBuild, nowInMap)}');

    await tester.tap(find.byKey(const ValueKey('dots_0')));
    await tester.pumpAndSettle();
    debugPrint('A: menu open                     = ${menuVisible()}');

    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();

    debugPrint('A: menu visible after close tap  = ${menuVisible()}');
    debugPrint('A: mapCtrl.menuIsShowing         = ${k.currentState!.controllers[0]!.menuIsShowing}');
    debugPrint('A: boundAtBuild.menuIsShowing    = ${boundAtBuild.menuIsShowing}');
  });
}
