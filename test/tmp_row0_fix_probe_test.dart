import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:popup_menu_2/popup_menu_2.dart';
import 'package:flutter_vocabulary_app/features/word_input/widgets/translation_dots_button.dart';

/// Three probe scenarios, no assertions -- the printed values are the evidence.
///
/// A: row N created AFTER the map clear  -> healthy?  (the "second item works" half)
/// B: row 0 that predates the clear     -> broken?   (the reported half)
/// C: same as B but the map is NOT cleared, only pruned -> fixed?
class Host extends StatefulWidget {
  const Host({super.key, required this.rows, required this.clearMode});
  final int rows;
  final String clearMode; // 'clear' | 'prune' | 'none'
  @override
  State<Host> createState() => HostState();
}

class HostState extends State<Host> {
  final Map<int, CustomPopupMenuController> controllers = {};

  void wipeMap() {
    setState(() {
      if (widget.clearMode == 'clear') {
        controllers.clear();
      } else if (widget.clearMode == 'prune') {
        // The proposed fix: keep controllers for indices still in range.
        controllers.removeWhere((k, v) => k >= widget.rows);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: widget.rows,
      padding: const EdgeInsets.all(16),
      itemBuilder: (context, i) => SizedBox(
        height: 60,
        child: Row(
          children: [
            const Expanded(child: SizedBox()),
            TranslationDotsButton(
              key: ValueKey('dots_$i'),
              controller: controllers.putIfAbsent(i, () => CustomPopupMenuController()),
              options: null,
              onSelectTranslation: (_) {},
              onLoadTranslations: () async => null,
              onOpen: () {},
              onClose: () => controllers[i]?.hideMenu(),
            ),
          ],
        ),
      ),
    );
  }
}

bool menuVisible() => find
    .byWidgetPredicate((w) => w is Material && w.color == Colors.black87)
    .evaluate()
    .isNotEmpty;

String scenario(String mode, int rows, int openRow, {required bool wipeFirst}) {
  return '$mode rows=$rows open=$openRow wipeFirst=$wipeFirst';
}

void main() {
  for (final mode in <String>['clear', 'prune']) {
    for (final wipeFirst in <bool>[false, true]) {
      testWidgets('probe $mode wipeFirst=$wipeFirst', (tester) async {
        tester.view.physicalSize = const Size(1170, 2532);
        tester.view.devicePixelRatio = 3.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final k = GlobalKey<HostState>();
        // Two rows so there is a row 0 that predates the wipe and a row 1 that does not.
        await tester.pumpWidget(MaterialApp(
          home: Scaffold(body: Host(key: k, rows: 2, clearMode: mode)),
        ));
        await tester.pumpAndSettle();

        final row0Before = k.currentState!.controllers[0];
        if (wipeFirst) {
          // Emulates the restore/reorder wipe happening BEFORE the user taps.
          k.currentState!.wipeMap();
          await tester.pumpAndSettle();
        }

        for (final row in <int>[0, 1]) {
          final before = k.currentState!.controllers[row];
          await tester.tap(find.byKey(ValueKey('dots_$row')));
          await tester.pumpAndSettle();
          final openedVisible = menuVisible();
          await tester.tap(find.byIcon(Icons.close));
          await tester.pumpAndSettle();
          final stillVisible = menuVisible();
          final mapCtrl = k.currentState!.controllers[row];
          debugPrint('PROBE $mode wipeFirst=$wipeFirst row=$row '
              'mapIdentityChanged=${!identical(before, mapCtrl)} '
              'opened=$openedVisible closedOk=${!stillVisible} '
              'mapShowing=${mapCtrl?.menuIsShowing}');
          if (stillVisible) {
            // Close the stuck menu so the next row starts clean.
            mapCtrl?.hideMenu();
            debugPrint('PROBE   -> stuck; mapHide did not help. row0Before=${row0Before.hashCode}');
            break;
          }
        }
      });
    }
  }
}
