import 'package:flutter/material.dart';

import '../app_decor.dart';
import '../theme_kit.dart';
import 'matcha.dart';
import 'themes.dart';

const classic = AppThemeSpec(
  id: AppThemeId.classic,
  name: 'Classic',
  description: 'The lilac rows you know',
  build: classicTheme,
);

/// The Classic theme: the app's colours from before themes, with Matcha's
/// fonts and text colours (owner, 2026-10-17).
ThemeData classicTheme() {
  final matcha = matchaScheme();
  final base = ThemeData(
    colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple).copyWith(
      inversePrimary: classicTopBarColor,
      onSurface: matcha.onSurface,
      onSurfaceVariant: matcha.onSurfaceVariant,
    ),
    appBarTheme: const AppBarTheme(backgroundColor: classicTopBarColor),
    useMaterial3: true,
    fontFamily: matchaBodyFont,
    extensions: const [AppDecor.classic],
  );
  final textTheme = withDisplayFont(base.textTheme, matchaDisplayFont);
  return base.copyWith(
    textTheme: textTheme,
    // The bar title as in Matcha, the same size (owner, 2026-10-17).
    appBarTheme: base.appBarTheme.copyWith(
      titleTextStyle:
          textTheme.titleLarge?.copyWith(color: base.colorScheme.onSurface),
    ),
  );
}
