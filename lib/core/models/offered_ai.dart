// The AIs a learner may choose for the three steps of a story run, as the
// Worker serves them (mnemonic-story ADR-0004, GET /story/models), and the
// learner's choice among them (AC-12, AC-13). Plain Dart: nothing here is
// stored in Isar.

/// The three steps whose AI the learner picks.
enum AiRole { story, prompt, picture }

/// One AI on the Worker's offered list. Text AIs carry per-million-token prices
/// and the list-price estimate for a 15-word group; picture AIs carry a price
/// per picture ([approx] when that price is itself approximate).
class OfferedAi {
  final String id;
  final String name;
  final String provider;

  /// 'text' (story and picture prompt writers) or 'picture'.
  final String role;
  final double? inputUsdPerMTok;
  final double? outputUsdPerMTok;
  final double? estimate15Usd;
  final double? usdPerPicture;
  final bool approx;

  const OfferedAi({
    required this.id,
    required this.name,
    required this.provider,
    required this.role,
    this.inputUsdPerMTok,
    this.outputUsdPerMTok,
    this.estimate15Usd,
    this.usdPerPicture,
    this.approx = false,
  });

  bool get isText => role == 'text';
  bool get isPicture => role == 'picture';

  factory OfferedAi.fromJson(Map<String, dynamic> json) => OfferedAi(
        id: json['id'] as String,
        name: json['name'] as String,
        provider: json['provider'] as String,
        role: json['role'] as String,
        inputUsdPerMTok: (json['inputUsdPerMTok'] as num?)?.toDouble(),
        outputUsdPerMTok: (json['outputUsdPerMTok'] as num?)?.toDouble(),
        estimate15Usd: (json['estimate15Usd'] as num?)?.toDouble(),
        usdPerPicture: (json['usdPerPicture'] as num?)?.toDouble(),
        approx: json['approx'] as bool? ?? false,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'provider': provider,
        'role': role,
        if (inputUsdPerMTok != null) 'inputUsdPerMTok': inputUsdPerMTok,
        if (outputUsdPerMTok != null) 'outputUsdPerMTok': outputUsdPerMTok,
        if (estimate15Usd != null) 'estimate15Usd': estimate15Usd,
        if (usdPerPicture != null) 'usdPerPicture': usdPerPicture,
        if (approx) 'approx': approx,
      };
}

/// The AI id for each step.
class AiChoice {
  final String story;
  final String prompt;
  final String picture;
  const AiChoice({required this.story, required this.prompt, required this.picture});

  String of(AiRole role) => switch (role) {
        AiRole.story => story,
        AiRole.prompt => prompt,
        AiRole.picture => picture,
      };

  AiChoice withRole(AiRole role, String id) => AiChoice(
        story: role == AiRole.story ? id : story,
        prompt: role == AiRole.prompt ? id : prompt,
        picture: role == AiRole.picture ? id : picture,
      );

  @override
  bool operator ==(Object other) =>
      other is AiChoice && other.story == story && other.prompt == prompt && other.picture == picture;

  @override
  int get hashCode => Object.hash(story, prompt, picture);

  @override
  String toString() => 'AiChoice($story, $prompt, $picture)';
}

/// The Worker's offered list: prices, the date they come from and the default
/// AI for each step.
class OfferedAiList {
  final String pricesAsOf;
  final AiChoice defaults;
  final List<OfferedAi> models;

  const OfferedAiList({required this.pricesAsOf, required this.defaults, required this.models});

  /// What the app can use when it has never reached the Worker: the default
  /// AIs only (AC-13).
  static const fallback = OfferedAiList(
    pricesAsOf: '2026-10-07',
    defaults: AiChoice(story: 'claude-sonnet-5-5', prompt: 'claude-sonnet-5-5', picture: 'grok-imagine-image-2.0'),
    models: [
      OfferedAi(
        id: 'claude-sonnet-5-5',
        name: 'Sonnet 5.5',
        provider: 'anthropic',
        role: 'text',
        inputUsdPerMTok: 2,
        outputUsdPerMTok: 10,
        estimate15Usd: 0.008,
      ),
      OfferedAi(
        id: 'grok-imagine-image-2.0',
        name: 'Grok Imagine 2.0',
        provider: 'xai',
        role: 'picture',
        usdPerPicture: 0.08,
      ),
    ],
  );

  List<OfferedAi> get textModels => [for (final m in models) if (m.isText) m];
  List<OfferedAi> get pictureModels => [for (final m in models) if (m.isPicture) m];

  OfferedAi? byId(String id) {
    for (final m in models) {
      if (m.id == id) return m;
    }
    return null;
  }

  /// The AIs that may be chosen for [role].
  List<OfferedAi> forRole(AiRole role) => role == AiRole.picture ? pictureModels : textModels;

  factory OfferedAiList.fromJson(Map<String, dynamic> json) {
    final d = json['defaults'] as Map<String, dynamic>;
    return OfferedAiList(
      pricesAsOf: json['pricesAsOf'] as String,
      defaults: AiChoice(
        story: d['story'] as String,
        prompt: d['prompt'] as String,
        picture: d['picture'] as String,
      ),
      models: [
        for (final m in json['models'] as List<dynamic>) OfferedAi.fromJson(m as Map<String, dynamic>),
      ],
    );
  }

  Map<String, dynamic> toJson() => {
        'pricesAsOf': pricesAsOf,
        'defaults': {'story': defaults.story, 'prompt': defaults.prompt, 'picture': defaults.picture},
        'models': [for (final m in models) m.toJson()],
      };
}

/// Where the last fetched [OfferedAiList] is kept (shared_preferences).
class OfferedAiCache {
  static const key = 'story_offered_ais';
}

/// The learner's saved choice, before it is checked against the offered list:
/// the ids chosen, and the names they had so "<name> is no longer available"
/// can be said once the AI has left the list. A role absent here was never chosen.
class StoredAiChoice {
  final Map<AiRole, String> ids;
  final Map<AiRole, String> names;
  const StoredAiChoice({this.ids = const {}, this.names = const {}});
}

/// A [StoredAiChoice] checked against the offered list (AC-13).
class ResolvedAiChoice {
  /// An offered AI for every step: the saved one, else the default.
  final AiChoice choice;

  /// Steps whose saved AI is no longer offered, with its name; those steps
  /// have fallen back to the default.
  final Map<AiRole, String> unavailable;
  const ResolvedAiChoice(this.choice, this.unavailable);
}

/// Keeps each saved AI that is still offered for its step; anything else
/// falls back to the default for it (AC-13). No story run may start with
/// an AI that is not offered, so start runs from [ResolvedAiChoice.choice].
ResolvedAiChoice resolveAiChoice(StoredAiChoice stored, OfferedAiList offered) {
  final unavailable = <AiRole, String>{};
  String pick(AiRole role) {
    final id = stored.ids[role];
    if (id == null) return offered.defaults.of(role);
    if (offered.forRole(role).any((m) => m.id == id)) return id;
    unavailable[role] = stored.names[role] ?? id;
    return offered.defaults.of(role);
  }

  final choice = AiChoice(
    story: pick(AiRole.story),
    prompt: pick(AiRole.prompt),
    picture: pick(AiRole.picture),
  );
  return ResolvedAiChoice(choice, unavailable);
}
