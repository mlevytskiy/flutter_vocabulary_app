import 'package:flutter/material.dart';

import 'app_decor.dart';
import 'themes/themes.dart';

/// One theme: its stored id, what the App settings page shows, and [build],
/// which makes the app's [ThemeData] (usually with [buildTheme]).
class AppThemeSpec {
  const AppThemeSpec({
    required this.id,
    required this.name,
    required this.description,
    required this.build,
  });

  final AppThemeId id;
  final String name;
  final String description;
  final ThemeData Function() build;

  static AppThemeSpec of(AppThemeId id) =>
      appThemes.firstWhere((t) => t.id == id);
}

/// [text] with [display] for display, headline and the large title; the rest
/// keeps the theme's body font.
TextTheme withDisplayFont(TextTheme text, String display) {
  TextStyle? d(TextStyle? s) => s?.copyWith(fontFamily: display);
  return text.copyWith(
    displayLarge: d(text.displayLarge),
    displayMedium: d(text.displayMedium),
    displaySmall: d(text.displaySmall),
    headlineLarge: d(text.headlineLarge),
    headlineMedium: d(text.headlineMedium),
    headlineSmall: d(text.headlineSmall),
    titleLarge: d(text.titleLarge),
  );
}

/// A themed [ThemeData]: [scheme] and [decor], [bodyFont] for text and
/// [displayFont] for titles, [radius] for buttons, fields, cards and sheets.
/// A null [bodyFont] is the platform's own sans; [scaffold] is the page colour
/// (default the surface) and [onTopBar] the top bar's text and icons.
ThemeData buildTheme({
  required ColorScheme scheme,
  required AppDecor decor,
  required String? bodyFont,
  String? displayFont,
  double radius = 16,
  Color? scaffold,
  Color? onTopBar,
}) {
  final base = ThemeData(
    colorScheme: scheme.copyWith(inversePrimary: decor.topBar),
    useMaterial3: true,
    fontFamily: bodyFont,
  );
  final display = displayFont ?? bodyFont;
  final textTheme = display == null
      ? base.textTheme
      : withDisplayFont(base.textTheme, display);
  final shape =
      RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius));
  final barText = onTopBar ?? scheme.onSurface;
  return base.copyWith(
    textTheme: textTheme,
    scaffoldBackgroundColor: scaffold ?? scheme.surface,
    appBarTheme: AppBarTheme(
      backgroundColor: decor.topBar,
      foregroundColor: barText,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: textTheme.titleLarge?.copyWith(color: barText),
    ),
    cardTheme: CardThemeData(shape: shape),
    dialogTheme: DialogThemeData(shape: shape),
    bottomSheetTheme: BottomSheetThemeData(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
            top: Radius.circular(radius == 0 ? 0 : radius + 8)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      border:
          OutlineInputBorder(borderRadius: BorderRadius.circular(radius * 0.6)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(shape: shape),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(shape: shape),
    ),
    chipTheme: base.chipTheme.copyWith(
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius)),
    ),
    drawerTheme: DrawerThemeData(backgroundColor: scheme.surface),
    extensions: [decor],
  );
}

/// A Material colour scheme grown from [seed], with the named roles pinned.
ColorScheme seedScheme(
  Color seed,
  Brightness brightness, {
  DynamicSchemeVariant variant = DynamicSchemeVariant.tonalSpot,
  Color? primary,
  Color? onPrimary,
  Color? secondary,
  Color? tertiary,
  Color? surface,
  Color? onSurface,
  Color? secondaryContainer,
  Color? onSecondaryContainer,
  Color? tertiaryContainer,
  Color? onTertiaryContainer,
}) =>
    ColorScheme.fromSeed(
      seedColor: seed,
      brightness: brightness,
      dynamicSchemeVariant: variant,
      primary: primary,
      onPrimary: onPrimary,
      secondary: secondary,
      tertiary: tertiary,
      surface: surface,
      onSurface: onSurface,
      secondaryContainer: secondaryContainer,
      onSecondaryContainer: onSecondaryContainer,
      tertiaryContainer: tertiaryContainer,
      onTertiaryContainer: onTertiaryContainer,
    );
