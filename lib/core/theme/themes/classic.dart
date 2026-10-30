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
/// fonts and near-black text (owner, 2026-10-17); its dark greens are
/// purples since 2026-10-18 ([classicDarkPurple]).
ThemeData classicTheme() {
  final matcha = matchaScheme();
  final base = ThemeData(
    colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple).copyWith(
      inversePrimary: classicTopBarColor,
      onSurface: matcha.onSurface,
      // Matcha's dark olive gave way to a purple grey (owner, 2026-10-18).
      onSurfaceVariant: const Color(0xFF49454E),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: classicTopBarColor,
      leadingWidth: barLeadingWidth,
      titleSpacing: barTitleSpacing,
    ),
    useMaterial3: true,
    fontFamily: matchaBodyFont,
    // The constructor's defaults are Classic's slots (rateForgot … rateEasy
    // included).
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
