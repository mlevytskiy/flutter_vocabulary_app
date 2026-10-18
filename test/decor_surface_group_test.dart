import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_vocabulary_app/core/theme/app_theme.dart';

void main() {
  // Tests run as Android: the blur is live only where asked, or everywhere
  // when a test says so.
  tearDown(() => DecorSurface.debugBlurEverywhere = null);

  Widget rows({required bool grouped, Widget Function(Widget)? wrap}) {
    Widget list = Column(children: [
      for (var i = 0; i < 3; i++)
        DecorSurface(padding: EdgeInsets.zero, child: Text('row $i')),
    ]);
    if (wrap != null) list = wrap(list);
    return MaterialApp(
      theme: AppThemeSpec.of(AppThemeId.aurora).build(),
      home: Scaffold(body: grouped ? BackdropGroup(child: list) : list),
    );
  }

  List<BackdropFilter> filters(WidgetTester t) =>
      t.widgetList<BackdropFilter>(find.byType(BackdropFilter)).toList();

  testWidgets('Aurora rows under a BackdropGroup share its backdrop read',
      (t) async {
    DecorSurface.debugBlurEverywhere = true;
    await t.pumpWidget(rows(grouped: true));
    final key = t.widget<BackdropGroup>(find.byType(BackdropGroup)).backdropKey;
    expect(filters(t), hasLength(3));
    for (final f in filters(t)) {
      expect(f.enabled, isTrue);
      expect(f.backdropGroupKey, same(key));
    }
  });

  testWidgets('rows outside a group still blur on their own', (t) async {
    DecorSurface.debugBlurEverywhere = true;
    await t.pumpWidget(rows(grouped: false));
    for (final f in filters(t)) {
      expect(f.enabled, isTrue);
      expect(f.backdropGroupKey, isNull);
    }
  });

  testWidgets('on Android a row at rest draws no live blur', (t) async {
    expect(DecorSurface.blurEverywhere, isFalse,
        reason: 'widget tests run as Android');
    await t.pumpWidget(rows(grouped: true));
    expect(filters(t), hasLength(3));
    for (final f in filters(t)) {
      expect(f.enabled, isFalse);
    }
    // The rounded fill and border are the row's own, as in every theme.
    final box = t.widget<Container>(find
        .descendant(of: find.byType(DecorSurface), matching: find.byType(Container))
        .first);
    final decoration = box.decoration! as BoxDecoration;
    expect(decoration.borderRadius, BorderRadius.circular(18));
    expect(decoration.color, AppDecor.of(t.element(find.text('row 0'))).wordRow);
  });

  testWidgets('on Android a row under LiveBlur keeps the frosted glass',
      (t) async {
    await t.pumpWidget(
        rows(grouped: true, wrap: (list) => LiveBlur(child: list)));
    for (final f in filters(t)) {
      expect(f.enabled, isTrue);
    }
  });

  testWidgets('a theme without a blur never blurs, LiveBlur or not',
      (t) async {
    DecorSurface.debugBlurEverywhere = true;
    await t.pumpWidget(MaterialApp(
      theme: AppThemeSpec.of(AppThemeId.classic).build(),
      home: const Scaffold(
        body: LiveBlur(
          child: DecorSurface(padding: EdgeInsets.zero, child: Text('r')),
        ),
      ),
    ));
    expect(filters(t).single.enabled, isFalse);
  });
}
