import '../app_decor.dart';
import '../theme_kit.dart';
import 'amber_terminal.dart';
import 'aurora.dart';
import 'classic.dart';
import 'matcha.dart';
import 'windows95.dart';

/// The themes of the App settings page (app-themes, owner 2026-10-17).
/// Stored by name; a stored name no longer here reads as [classic].
///
/// To add a theme:
/// 1. Copy a theme file next to this one (`matcha.dart` for a light theme,
///    `aurora.dart` for a dark one) and give it a new name, description,
///    colour scheme and [AppDecor]. Slots left out keep Classic's values.
/// 2. Add its id below and the theme to [appThemes].
/// 3. A new font goes in `pubspec.yaml` and `registerFontLicenses` in
///    `lib/main.dart` (assets need the owner's approval, CLAUDE.md rule 5).
/// Extras beyond [buildTheme]'s parameters (square buttons, borders): take
/// what it returns and `copyWith` them, as `windows95.dart` does. A colour
/// that a screen still hard-codes becomes a new [AppDecor] slot whose default
/// is the old constant.
enum AppThemeId {
  classic,
  aurora,
  matcha,
  amberTerminal,
  windows95,
}

/// The App settings gallery, in this order.
final appThemes = <AppThemeSpec>[
  classic,
  aurora,
  matcha,
  amberTerminal,
  windows95,
];
