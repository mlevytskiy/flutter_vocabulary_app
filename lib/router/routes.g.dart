// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'routes.dart';

// **************************************************************************
// GoRouterGenerator
// **************************************************************************

List<RouteBase> get $appRoutes => [
      $menuShellRoute,
    ];

RouteBase get $menuShellRoute => StatefulShellRouteData.$route(
      factory: $MenuShellRouteExtension._fromState,
      branches: [
        StatefulShellBranchData.$branch(
          routes: [
            GoRouteData.$route(
              path: '/',
              factory: _$CollectionsRoute._fromState,
              routes: [
                GoRouteData.$route(
                  path: 'recycle-bin',
                  factory: _$RecycleBinRoute._fromState,
                ),
                GoRouteData.$route(
                  path: 'collections-settings',
                  factory: _$CollectionsSettingsRoute._fromState,
                ),
              ],
            ),
          ],
        ),
        StatefulShellBranchData.$branch(
          routes: [
            GoRouteData.$route(
              path: '/words',
              factory: _$WordsRoute._fromState,
              routes: [
                GoRouteData.$route(
                  path: 'table',
                  factory: _$WordsTableRoute._fromState,
                  routes: [
                    GoRouteData.$route(
                      path: 'learn',
                      factory: _$LearnRoute._fromState,
                      routes: [
                        GoRouteData.$route(
                          path: 'soon',
                          factory: _$ComingSoonRoute._fromState,
                        ),
                        GoRouteData.$route(
                          path: 'story',
                          factory: _$StoryRoute._fromState,
                        ),
                        GoRouteData.$route(
                          path: 'exercise',
                          factory: _$ExerciseRoute._fromState,
                        ),
                        GoRouteData.$route(
                          path: 'dialogue',
                          factory: _$DialogueRoute._fromState,
                        ),
                      ],
                    ),
                    GoRouteData.$route(
                      path: 'session',
                      factory: _$LearningSessionRoute._fromState,
                    ),
                    GoRouteData.$route(
                      path: 'talk',
                      factory: _$TalkRoute._fromState,
                    ),
                    GoRouteData.$route(
                      path: 'settings',
                      factory: _$WordsSettingsRoute._fromState,
                      routes: [
                        GoRouteData.$route(
                          path: 'runs',
                          factory: _$StoryRunsRoute._fromState,
                          routes: [
                            GoRouteData.$route(
                              path: ':runId',
                              factory: _$StoryRunRoute._fromState,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
                GoRouteData.$route(
                  path: 'notes',
                  factory: _$NotesRoute._fromState,
                ),
                GoRouteData.$route(
                  path: 'photo/:sourceId',
                  factory: _$PhotoViewerRoute._fromState,
                ),
                GoRouteData.$route(
                  path: 'settings',
                  factory: _$SettingsRoute._fromState,
                ),
              ],
            ),
          ],
        ),
        StatefulShellBranchData.$branch(
          routes: [
            GoRouteData.$route(
              path: '/app-settings',
              factory: _$AppSettingsRoute._fromState,
            ),
          ],
        ),
      ],
    );

extension $MenuShellRouteExtension on MenuShellRoute {
  static MenuShellRoute _fromState(GoRouterState state) =>
      const MenuShellRoute();
}

mixin _$CollectionsRoute on GoRouteData {
  static CollectionsRoute _fromState(GoRouterState state) => CollectionsRoute(
        tagKind: _$convertMapValue(
            'tag-kind', state.uri.queryParameters, _$TagKindEnumMap._$fromName),
        tag: state.uri.queryParameters['tag'],
      );

  CollectionsRoute get _self => this as CollectionsRoute;

  @override
  String get location => GoRouteData.$location(
        '/',
        queryParams: {
          if (_self.tagKind != null)
            'tag-kind': _$TagKindEnumMap[_self.tagKind!],
          if (_self.tag != null) 'tag': _self.tag,
        },
      );

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}

const _$TagKindEnumMap = {
  TagKind.origin: 'origin',
  TagKind.topic: 'topic',
};

mixin _$RecycleBinRoute on GoRouteData {
  static RecycleBinRoute _fromState(GoRouterState state) =>
      const RecycleBinRoute();

  @override
  String get location => GoRouteData.$location(
        '/recycle-bin',
      );

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}

mixin _$CollectionsSettingsRoute on GoRouteData {
  static CollectionsSettingsRoute _fromState(GoRouterState state) =>
      const CollectionsSettingsRoute();

  @override
  String get location => GoRouteData.$location(
        '/collections-settings',
      );

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}

mixin _$WordsRoute on GoRouteData {
  static WordsRoute _fromState(GoRouterState state) => const WordsRoute();

  @override
  String get location => GoRouteData.$location(
        '/words',
      );

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}

mixin _$WordsTableRoute on GoRouteData {
  static WordsTableRoute _fromState(GoRouterState state) => WordsTableRoute(
        collectionId: state.uri.queryParameters['collection-id'],
      );

  WordsTableRoute get _self => this as WordsTableRoute;

  @override
  String get location => GoRouteData.$location(
        '/words/table',
        queryParams: {
          if (_self.collectionId != null) 'collection-id': _self.collectionId,
        },
      );

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}

mixin _$LearnRoute on GoRouteData {
  static LearnRoute _fromState(GoRouterState state) => LearnRoute(
        collectionId: state.uri.queryParameters['collection-id'],
      );

  LearnRoute get _self => this as LearnRoute;

  @override
  String get location => GoRouteData.$location(
        '/words/table/learn',
        queryParams: {
          if (_self.collectionId != null) 'collection-id': _self.collectionId,
        },
      );

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}

mixin _$ComingSoonRoute on GoRouteData {
  static ComingSoonRoute _fromState(GoRouterState state) => ComingSoonRoute(
        exercise: state.uri.queryParameters['exercise']!,
      );

  ComingSoonRoute get _self => this as ComingSoonRoute;

  @override
  String get location => GoRouteData.$location(
        '/words/table/learn/soon',
        queryParams: {
          'exercise': _self.exercise,
        },
      );

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}

mixin _$StoryRoute on GoRouteData {
  static StoryRoute _fromState(GoRouterState state) => StoryRoute(
        collectionId: state.uri.queryParameters['collection-id'],
        groupId: state.uri.queryParameters['group-id']!,
      );

  StoryRoute get _self => this as StoryRoute;

  @override
  String get location => GoRouteData.$location(
        '/words/table/learn/story',
        queryParams: {
          if (_self.collectionId != null) 'collection-id': _self.collectionId,
          'group-id': _self.groupId,
        },
      );

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}

mixin _$ExerciseRoute on GoRouteData {
  static ExerciseRoute _fromState(GoRouterState state) => ExerciseRoute(
        collectionId: state.uri.queryParameters['collection-id'],
        exercise: state.uri.queryParameters['exercise']!,
        groupId: state.uri.queryParameters['group-id']!,
      );

  ExerciseRoute get _self => this as ExerciseRoute;

  @override
  String get location => GoRouteData.$location(
        '/words/table/learn/exercise',
        queryParams: {
          if (_self.collectionId != null) 'collection-id': _self.collectionId,
          'exercise': _self.exercise,
          'group-id': _self.groupId,
        },
      );

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}

mixin _$DialogueRoute on GoRouteData {
  static DialogueRoute _fromState(GoRouterState state) => DialogueRoute(
        collectionId: state.uri.queryParameters['collection-id'],
        groupId: state.uri.queryParameters['group-id']!,
      );

  DialogueRoute get _self => this as DialogueRoute;

  @override
  String get location => GoRouteData.$location(
        '/words/table/learn/dialogue',
        queryParams: {
          if (_self.collectionId != null) 'collection-id': _self.collectionId,
          'group-id': _self.groupId,
        },
      );

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}

mixin _$LearningSessionRoute on GoRouteData {
  static LearningSessionRoute _fromState(GoRouterState state) =>
      LearningSessionRoute(
        collectionId: state.uri.queryParameters['collection-id'],
        split: _$convertMapValue(
                'split', state.uri.queryParameters, _$boolConverter) ??
            true,
        rowIds: state.uri.queryParameters['row-ids'],
      );

  LearningSessionRoute get _self => this as LearningSessionRoute;

  @override
  String get location => GoRouteData.$location(
        '/words/table/session',
        queryParams: {
          if (_self.collectionId != null) 'collection-id': _self.collectionId,
          if (_self.split != true) 'split': _self.split.toString(),
          if (_self.rowIds != null) 'row-ids': _self.rowIds,
        },
      );

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}

mixin _$TalkRoute on GoRouteData {
  static TalkRoute _fromState(GoRouterState state) => TalkRoute(
        collectionId: state.uri.queryParameters['collection-id'],
        split: _$convertMapValue(
                'split', state.uri.queryParameters, _$boolConverter) ??
            true,
      );

  TalkRoute get _self => this as TalkRoute;

  @override
  String get location => GoRouteData.$location(
        '/words/table/talk',
        queryParams: {
          if (_self.collectionId != null) 'collection-id': _self.collectionId,
          if (_self.split != true) 'split': _self.split.toString(),
        },
      );

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}

mixin _$WordsSettingsRoute on GoRouteData {
  static WordsSettingsRoute _fromState(GoRouterState state) =>
      WordsSettingsRoute(
        collectionId: state.uri.queryParameters['collection-id'],
      );

  WordsSettingsRoute get _self => this as WordsSettingsRoute;

  @override
  String get location => GoRouteData.$location(
        '/words/table/settings',
        queryParams: {
          if (_self.collectionId != null) 'collection-id': _self.collectionId,
        },
      );

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}

mixin _$StoryRunsRoute on GoRouteData {
  static StoryRunsRoute _fromState(GoRouterState state) =>
      const StoryRunsRoute();

  @override
  String get location => GoRouteData.$location(
        '/words/table/settings/runs',
      );

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}

mixin _$StoryRunRoute on GoRouteData {
  static StoryRunRoute _fromState(GoRouterState state) => StoryRunRoute(
        runId: state.pathParameters['runId']!,
      );

  StoryRunRoute get _self => this as StoryRunRoute;

  @override
  String get location => GoRouteData.$location(
        '/words/table/settings/runs/${Uri.encodeComponent(_self.runId)}',
      );

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}

mixin _$NotesRoute on GoRouteData {
  static NotesRoute _fromState(GoRouterState state) => NotesRoute(
        selectedId: state.uri.queryParameters['selected-id'],
      );

  NotesRoute get _self => this as NotesRoute;

  @override
  String get location => GoRouteData.$location(
        '/words/notes',
        queryParams: {
          if (_self.selectedId != null) 'selected-id': _self.selectedId,
        },
      );

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}

mixin _$PhotoViewerRoute on GoRouteData {
  static PhotoViewerRoute _fromState(GoRouterState state) => PhotoViewerRoute(
        sourceId: state.pathParameters['sourceId']!,
      );

  PhotoViewerRoute get _self => this as PhotoViewerRoute;

  @override
  String get location => GoRouteData.$location(
        '/words/photo/${Uri.encodeComponent(_self.sourceId)}',
      );

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}

mixin _$SettingsRoute on GoRouteData {
  static SettingsRoute _fromState(GoRouterState state) => const SettingsRoute();

  @override
  String get location => GoRouteData.$location(
        '/words/settings',
      );

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}

mixin _$AppSettingsRoute on GoRouteData {
  static AppSettingsRoute _fromState(GoRouterState state) =>
      const AppSettingsRoute();

  @override
  String get location => GoRouteData.$location(
        '/app-settings',
      );

  @override
  void go(BuildContext context) => context.go(location);

  @override
  Future<T?> push<T>(BuildContext context) => context.push<T>(location);

  @override
  void pushReplacement(BuildContext context) =>
      context.pushReplacement(location);

  @override
  void replace(BuildContext context) => context.replace(location);
}

T? _$convertMapValue<T>(
  String key,
  Map<String, String> map,
  T? Function(String) converter,
) {
  final value = map[key];
  return value == null ? null : converter(value);
}

extension<T extends Enum> on Map<T, String> {
  T? _$fromName(String? value) =>
      entries.where((element) => element.value == value).firstOrNull?.key;
}

bool _$boolConverter(String value) {
  switch (value) {
    case 'true':
      return true;
    case 'false':
      return false;
    default:
      throw UnsupportedError('Cannot convert "$value" into a bool.');
  }
}
