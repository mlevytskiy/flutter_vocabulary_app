import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_vocabulary_app/core/theme/app_theme.dart';

void main() {
  Widget rows({required bool grouped}) {
    final list = Column(children: [
      for (var i = 0; i < 3; i++)
        DecorSurface(padding: EdgeInsets.zero, child: Text('row $i')),
    ]);
    return MaterialApp(
      theme: AppThemeSpec.of(AppThemeId.aurora).build(),
      home: Scaffold(body: grouped ? BackdropGroup(child: list) : list),
    );
  }

  testWidgets('Aurora rows under a BackdropGroup share its backdrop read',
      (t) async {
    await t.pumpWidget(rows(grouped: true));
    final key = t.widget<BackdropGroup>(find.byType(BackdropGroup)).backdropKey;
    final filters =
        t.widgetList<BackdropFilter>(find.byType(BackdropFilter)).toList();
    expect(filters, hasLength(3));
    for (final f in filters) {
      expect(f.enabled, isTrue);
      expect(f.backdropGroupKey, same(key));
    }
  });

  testWidgets('rows outside a group still blur on their own', (t) async {
    await t.pumpWidget(rows(grouped: false));
    for (final f in t.widgetList<BackdropFilter>(find.byType(BackdropFilter))) {
      expect(f.enabled, isTrue);
      expect(f.backdropGroupKey, isNull);
    }
  });
}
