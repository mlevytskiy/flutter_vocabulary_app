import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app_restarter.dart';
import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';

/// App settings (app-themes, owner 2026-10-17): settings for the whole app,
/// opened from the side menu. The theme gallery (every theme as a small live
/// picture of the main screen; a tap switches the app to it) and the
/// new-user trial (owner, 2026-10-17).
class AppSettingsScreen extends ConsumerWidget {
  const AppSettingsScreen({super.key});

  static Key themeKey(AppThemeId id) => ValueKey('app-theme-${id.name}');
  static const startNewUserKey = Key('app-settings-start-new-user');
  static const restoreKey = Key('app-settings-restore-data');
  static const confirmKey = Key('app-settings-confirm');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(appThemeNotifierProvider);
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('App settings')),
      body: AppBackdrop(
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Theme', style: theme.textTheme.titleLarge),
                    const SizedBox(height: 4),
                    Text(
                      'Colours, fonts and shapes for the whole app',
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 220,
                  mainAxisSpacing: 14,
                  crossAxisSpacing: 14,
                  childAspectRatio: 0.66,
                ),
                delegate: SliverChildListDelegate([
                  for (final spec in appThemes)
                    _ThemeCard(
                      key: themeKey(spec.id),
                      spec: spec,
                      selected: spec.id == current,
                      onTap: () => ref
                          .read(appThemeNotifierProvider.notifier)
                          .set(spec.id),
                    ),
                ]),
              ),
            ),
            const SliverPadding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 32),
              sliver: SliverToBoxAdapter(child: _NewUserSection()),
            ),
          ],
        ),
      ),
    );
  }
}

/// "Try the app as a new user": puts the data aside and restarts empty; while
/// that is on, offers to bring the data back, deleting the trial's.
class _NewUserSection extends ConsumerWidget {
  const _NewUserSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final takenAt = ref.watch(newUserBackupProvider).valueOrNull;
    final muted = theme.textTheme.bodyMedium
        ?.copyWith(color: scheme.onSurfaceVariant);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(takenAt == null ? Icons.person_add_alt_1 : Icons.person,
                  color: scheme.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  takenAt == null
                      ? 'Try the app as a new user'
                      : 'You are seeing the app as a new user',
                  style: theme.textTheme.titleMedium,
                ),
              ),
            ]),
            const SizedBox(height: 8),
            if (takenAt == null) ...[
              Text(
                'See the app as someone who has just installed it. Your '
                'collections, words, photos and settings are put aside and '
                'the app restarts empty. Restore them here at any time.',
                style: muted,
              ),
              const SizedBox(height: 16),
              FilledButton.tonalIcon(
                key: AppSettingsScreen.startNewUserKey,
                onPressed: () => _start(context, ref),
                icon: const Icon(Icons.restart_alt),
                label: const Text('Start as a new user'),
              ),
            ] else ...[
              Text('Your data from ${_when(context, takenAt)} is saved.',
                  style: muted),
              const SizedBox(height: 16),
              FilledButton.icon(
                key: AppSettingsScreen.restoreKey,
                onPressed: () => _restore(context, ref, takenAt),
                icon: const Icon(Icons.settings_backup_restore),
                label: const Text('Restore my data'),
              ),
              const SizedBox(height: 8),
              Text('What you added as a new user will be deleted.',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: scheme.onSurfaceVariant)),
            ],
          ],
        ),
      ),
    );
  }

  static String _when(BuildContext context, DateTime at) {
    final l = MaterialLocalizations.of(context);
    return '${l.formatShortDate(at)}, '
        '${l.formatTimeOfDay(TimeOfDay.fromDateTime(at))}';
  }

  Future<void> _start(BuildContext context, WidgetRef ref) async {
    final ok = await _confirm(
      context,
      title: 'Start as a new user?',
      body: 'Your data is put aside and the app restarts empty. You can '
          'restore it from App settings.',
      action: 'Start',
    );
    if (!ok || !context.mounted) return;
    final trial = ref.read(newUserTrialProvider);
    await AppRestarter.of(context).restart(trial.start);
  }

  Future<void> _restore(
      BuildContext context, WidgetRef ref, DateTime takenAt) async {
    final ok = await _confirm(
      context,
      title: 'Restore your data?',
      body: 'Everything you added as a new user will be deleted, and your '
          'data from ${_when(context, takenAt)} comes back.',
      action: 'Delete and restore',
      destructive: true,
    );
    if (!ok || !context.mounted) return;
    final trial = ref.read(newUserTrialProvider);
    await AppRestarter.of(context).restart(trial.restore);
  }

  static Future<bool> _confirm(
    BuildContext context, {
    required String title,
    required String body,
    required String action,
    bool destructive = false,
  }) async {
    final scheme = Theme.of(context).colorScheme;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: AppSettingsScreen.confirmKey,
            style: destructive
                ? FilledButton.styleFrom(
                    backgroundColor: scheme.error,
                    foregroundColor: scheme.onError)
                : null,
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(action),
          ),
        ],
      ),
    );
    return ok ?? false;
  }
}

/// One theme: a miniature of the main screen drawn in the theme itself, its
/// name in the theme's display font and a line about it.
class _ThemeCard extends StatelessWidget {
  const _ThemeCard({
    super.key,
    required this.spec,
    required this.selected,
    required this.onTap,
  });

  final AppThemeSpec spec;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final outer = Theme.of(context).colorScheme;
    final data = spec.build();
    return Semantics(
      button: true,
      selected: selected,
      label: '${spec.name} theme',
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: selected ? outer.primary : outer.outlineVariant,
              width: selected ? 2.5 : 1,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(19),
            child: Theme(
              data: data,
              child: Builder(
                builder: (context) => Material(
                  color: data.scaffoldBackgroundColor,
                  child: Stack(
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Expanded(child: _Miniature()),
                          _Caption(spec: spec),
                        ],
                      ),
                      Positioned(
                        top: 8,
                        right: 8,
                        child: AnimatedScale(
                          scale: selected ? 1 : 0,
                          duration: const Duration(milliseconds: 220),
                          curve: Curves.easeOutBack,
                          child: CircleAvatar(
                            radius: 12,
                            backgroundColor: outer.primary,
                            child: Icon(Icons.check,
                                size: 16, color: outer.onPrimary),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Caption extends StatelessWidget {
  const _Caption({required this.spec});

  final AppThemeSpec spec;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      color: theme.colorScheme.surface,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            spec.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleLarge?.copyWith(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            spec.description,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

/// The main screen in small: the top bar, three word rows on the theme's
/// backdrop, and the two round buttons.
class _Miniature extends StatelessWidget {
  const _Miniature();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final decor = AppDecor.of(context);
    final onBar =
        theme.appBarTheme.foregroundColor ?? theme.colorScheme.onSurface;
    return AppBackdrop(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: 34,
            color: decor.topBar,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Row(
              children: [
                Text('Aa',
                    style: theme.textTheme.titleLarge
                        ?.copyWith(fontSize: 15, color: onBar)),
                const Spacer(),
                Container(
                  width: 26,
                  height: 14,
                  decoration: BoxDecoration(
                    color: decor.barButton,
                    borderRadius: BorderRadius.circular(7),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                  child: Column(
                    children: [
                      for (final pair in const [
                        ('apple', 'яблуко'),
                        ('brave', 'сміливий'),
                        ('cloud', 'хмара'),
                      ])
                        _MiniRow(word: pair.$1, translation: pair.$2),
                    ],
                  ),
                ),
                Positioned(
                  left: 8,
                  bottom: 8,
                  child: _MiniFab(
                      color: decor.fabAlt,
                      onColor: decor.onFabAlt,
                      icon: Icons.settings),
                ),
                Positioned(
                  right: 8,
                  bottom: 8,
                  child: _MiniFab(
                      color: decor.fab, onColor: decor.onFab, icon: Icons.add),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniRow extends StatelessWidget {
  const _MiniRow({required this.word, required this.translation});

  final String word;
  final String translation;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final decor = AppDecor.of(context);
    final style = theme.textTheme.bodySmall?.copyWith(
      fontSize: 10.5,
      color: theme.colorScheme.onSurface,
    );
    return DecorSurface(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Row(
        children: [
          Expanded(
              child: Text(word,
                  style: style, maxLines: 1, overflow: TextOverflow.clip)),
          Expanded(
              child: Text(translation,
                  style: style, maxLines: 1, overflow: TextOverflow.clip)),
          Icon(Icons.electric_bolt, size: 12, color: decor.rowIcon),
        ],
      ),
    );
  }
}

class _MiniFab extends StatelessWidget {
  const _MiniFab(
      {required this.color, required this.onColor, required this.icon});

  final Color color;
  final Color onColor;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Container(
        width: 26,
        height: 26,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.18),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(icon, size: 15, color: onColor),
      );
}
