import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_vocabulary_app/core/models/word_origin.dart';
import 'package:flutter_vocabulary_app/core/theme/app_decor.dart';
import 'package:flutter_vocabulary_app/core/theme/themes/themes.dart';
import 'package:flutter_vocabulary_app/features/words/widgets/translation_options_content.dart';

/// word-context T11: the Words screen's word popup shows the row's context
/// (spec AC-13) in two themes.
void main() {
  Future<void> pump(WidgetTester tester, AppThemeId id, String text,
      ContextKind kind) async {
    final theme = appThemes.firstWhere((t) => t.id == id).build();
    await tester.pumpWidget(MaterialApp(
      theme: theme,
      home: Scaffold(
        body: TranslationOptionsContent(
          contextText: text,
          contextKind: kind,
          onLoadTranslations: () async => null,
          onSelectTranslation: (_) {},
          onClose: () {},
        ),
      ),
    ));
  }

  for (final id in [AppThemeId.classic, AppThemeId.aurora]) {
    group(id.name, () {
      testWidgets('source context with the grey label', (tester) async {
        await pump(tester, id, 'He took a cab.', ContextKind.source);
        expect(find.text('from the source'), findsOneWidget);
        expect(find.text('written by AI'), findsNothing);
        expect(find.byIcon(Icons.auto_awesome), findsNothing);
        final t = tester.widget<Text>(find.text('He took a cab.'));
        expect(t.style?.fontStyle, FontStyle.italic);
      });

      testWidgets('AI context with the sparkle in aiAccent', (tester) async {
        await pump(tester, id, 'A cab waits.', ContextKind.ai);
        expect(find.text('written by AI'), findsOneWidget);
        final ctx = tester.element(find.text('written by AI'));
        final icon = tester.widget<Icon>(find.byIcon(Icons.auto_awesome));
        expect(icon.color, AppDecor.of(ctx).aiAccent);
        expect(find.text('A cab waits.'), findsOneWidget);
      });

      testWidgets('hidden when empty', (tester) async {
        await pump(tester, id, '', ContextKind.none);
        expect(find.byKey(const Key('popup-context')), findsNothing);
        await pump(tester, id, '', ContextKind.ai);
        expect(find.byKey(const Key('popup-context')), findsNothing);
      });
    });
  }
}
