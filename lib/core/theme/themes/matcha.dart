import 'package:flutter/material.dart';

import '../app_decor.dart';
import '../theme_kit.dart';
import 'themes.dart';

/// Matcha's leaf green, fonts and colour scheme; Classic shares the fonts and
/// the text colours (owner, 2026-10-17).
const matchaLeaf = Color(0xFF4E7A3A);
const matchaBodyFont = 'Nunito';
const matchaDisplayFont = 'Comfortaa';

ColorScheme matchaScheme() => seedScheme(matchaLeaf, Brightness.light,
    primary: matchaLeaf,
    surface: const Color(0xFFF3F6EE),
    secondaryContainer: const Color(0xFFDCE8CC),
    onSecondaryContainer: const Color(0xFF2F4A22),
    tertiaryContainer: const Color(0xFFF6E3C0),
    onTertiaryContainer: const Color(0xFF6B4A12));

final matcha = AppThemeSpec(
  id: AppThemeId.matcha,
  name: 'Matcha',
  description: 'Calm greens, round and soft',
  build: () {
    const leaf = matchaLeaf;
    const deep = Color(0xFF2F4A22);
    const honey = Color(0xFFE3A23B);
    return buildTheme(
      scheme: matchaScheme(),
      decor: const AppDecor(
        topBar: Color(0xFFDDE8CF),
        wordRow: Color(0xFFE4EDD8),
        wordRowRadius: 26,
        rowText: deep,
        rowSubtext: Color(0xFF5E6E52),
        rowIcon: leaf,
        aiAccent: Color(0xFF8A5A9E),
        rowHandle: Color(0xFF8DAA74),
        rowClose: Color(0xFF9DAF8C),
        popup: deep,
        onPopup: Color(0xFFF3F6EE),
        addAccent: leaf,
        fab: honey,
        fabActive: Color(0xFFC98A27),
        onFab: Colors.white,
        fabAlt: leaf,
        onFabAlt: Colors.white,
        dialPhoto: leaf,
        dialSubtitles: Color(0xFFC0564B),
        dialQuizlet: Color(0xFF4F8A8B),
        dialFolder: honey,
        onDial: Colors.white,
        barButton: Color(0xFFF7FAF2),
        paper: Color(0xFFF9FBF5),
        panel: Color(0xFFEEF4E6),
        panelBorder: Color(0x334E7A3A),
        muted: Color(0xFF8A9A7E),
        subtle: Color(0xFF6B7A60),
        strongIcon: Color(0xFF2F3A28),
        placeholder: Color(0xFFDDE5D3),
        onPlaceholder: Color(0x66000000),
        thumb: Color(0xFFC9D4BC),
        bin: Color(0xFF7A8B6E),
        binHot: Color(0xFFC0563B),
        binFolder: honey,
        right: Color(0xFF4E9A3A),
        wrong: Color(0xFFD0573E),
        picked: Color(0xFF8DAA74),
        pic50: Color(0xFFF2F7EC),
        pic100: Color(0xFFE4EDD8),
        pic200: Color(0xFFC9DCB2),
        pic500: Color(0xFF6B9A4F),
        pic600: leaf,
        glassEdge: Color(0xFFA8C78E),
        glassShadow: deep,
      ),
      bodyFont: matchaBodyFont,
      displayFont: matchaDisplayFont,
      radius: 24,
    );
  },
);
