import 'package:flutter/material.dart';

import '../app_decor.dart';
import '../theme_kit.dart';
import 'themes.dart';

const windows95 = AppThemeSpec(
  id: AppThemeId.windows95,
  name: 'Windows 95',
  description: 'Grey bevels on a teal desktop',
  build: windows95Theme,
);

/// Windows 95: the 16-colour palette, a teal desktop behind grey raised
/// rows (white top-left, dark grey bottom-right), a navy title bar and no
/// rounded corners anywhere.
ThemeData windows95Theme() {
  const desktop = Color(0xFF008080);
  const face = Color(0xFFC0C0C0);
  const shadow = Color(0xFF808080);
  const navy = Color(0xFF000080);
  const black = Colors.black;
  const white = Colors.white;
  const raised = Border(
    top: BorderSide(color: white, width: 2),
    left: BorderSide(color: white, width: 2),
    bottom: BorderSide(color: shadow, width: 2),
    right: BorderSide(color: shadow, width: 2),
  );
  const sunken = BorderSide(color: shadow);
  final scheme = seedScheme(navy, Brightness.light,
          variant: DynamicSchemeVariant.fidelity,
          primary: navy,
          onPrimary: white,
          secondary: desktop,
          tertiary: const Color(0xFF800080),
          surface: face,
          onSurface: black,
          secondaryContainer: const Color(0xFFD4D0C8),
          onSecondaryContainer: black,
          tertiaryContainer: const Color(0xFFFFFFE1),
          onTertiaryContainer: black)
      .copyWith(
    onSurfaceVariant: const Color(0xFF404040),
    outline: shadow,
    outlineVariant: shadow,
    surfaceContainerLowest: white,
    surfaceContainerLow: face,
    surfaceContainer: face,
    surfaceContainerHigh: face,
    surfaceContainerHighest: const Color(0xFFD4D0C8),
    surfaceTint: Colors.transparent,
  );
  final base = buildTheme(
    scheme: scheme,
    decor: const AppDecor(
      topBar: navy,
      wordRow: face,
      wordRowBorder: raised,
      wordRowRadius: 0,
      rowText: black,
      rowSubtext: Color(0xFF404040),
      rowIcon: navy,
      aiAccent: Color(0xFF008080),
      rowHandle: shadow,
      rowClose: Color(0xFF404040),
      popup: face,
      onPopup: black,
      addAccent: navy,
      contextAccent: navy,
      fab: face,
      fabActive: Color(0xFFA0A0A0),
      onFab: black,
      fabAlt: navy,
      onFabAlt: white,
      dialPhoto: Color(0xFF008000),
      dialSubtitles: Color(0xFF800080),
      dialQuizlet: Color(0xFF0000FF),
      dialFolder: Color(0xFF808000),
      onDial: white,
      barButton: face,
      onBarButton: black,
      paper: white,
      panel: face,
      panelBorder: shadow,
      muted: Color(0xFF202020),
      subtle: Color(0xFF404040),
      strongIcon: black,
      placeholder: face,
      onPlaceholder: shadow,
      thumb: shadow,
      bin: face,
      binHot: Color(0xFFFF0000),
      onBin: black,
      binFolder: Color(0xFFFFFF00),
      right: Color(0xFF008000),
      wrong: Color(0xFFFF0000),
      learnRight: Color(0xFF008000),
      onLearnRight: Color(0xFFFFFFFF),
      learnWrong: Color(0xFFFF0000),
      onLearnWrong: Color(0xFFFFFFFF),
      rateForgot: Color(0xFFFF0000),
      rateHard: Color(0xFFFF8000),
      rateMedium: Color(0xFF0000FF),
      rateEasy: Color(0xFF008000),
      picked: shadow,
      pic50: white,
      pic100: Color(0xFFFFFFC0),
      pic200: Color(0xFFF0E070),
      pic500: Color(0xFFC0A000),
      pic600: Color(0xFF808000),
      picPaper: white,
      glassTab: Color(0x66C0C0C0),
      glassPanel: Color(0x99C0C0C0),
      glassEdge: white,
      glassShadow: black,
      flowCard: face,
      flowCardBorder: shadow,
      flowCardShadow: Color(0x00000000),
      storyFrame: black,
      onStoryFrame: white,
      backdrop: LinearGradient(colors: [desktop, desktop]),
    ),
    bodyFont: null,
    radius: 0,
    onTopBar: white,
  );
  const square = RoundedRectangleBorder(side: sunken);
  const button = ButtonStyle(
    backgroundColor: WidgetStatePropertyAll(face),
    foregroundColor: WidgetStatePropertyAll(black),
    shape: WidgetStatePropertyAll(
        RoundedRectangleBorder(side: BorderSide(color: black))),
    elevation: WidgetStatePropertyAll(0),
  );
  return base.copyWith(
    appBarTheme: base.appBarTheme.copyWith(
      titleTextStyle: base.appBarTheme.titleTextStyle
          ?.copyWith(fontWeight: FontWeight.w700),
    ),
    filledButtonTheme: const FilledButtonThemeData(style: button),
    elevatedButtonTheme: const ElevatedButtonThemeData(style: button),
    outlinedButtonTheme: const OutlinedButtonThemeData(style: button),
    cardTheme: const CardThemeData(color: face, shape: square, elevation: 0),
    dialogTheme: const DialogThemeData(
        backgroundColor: face,
        shape: RoundedRectangleBorder(side: BorderSide(color: black))),
    popupMenuTheme: const PopupMenuThemeData(
        color: face,
        shape: RoundedRectangleBorder(side: BorderSide(color: black))),
    inputDecorationTheme: const InputDecorationTheme(
      filled: true,
      fillColor: white,
      border: OutlineInputBorder(borderRadius: BorderRadius.zero),
    ),
    drawerTheme: const DrawerThemeData(backgroundColor: face, shape: square),
  );
}
