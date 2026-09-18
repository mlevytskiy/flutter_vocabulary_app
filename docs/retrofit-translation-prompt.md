---
status: reference
updated_at: "2026-09-18"
---

# Prompt: redo the Google-translation layer with Retrofit + Dio

> **This is not the current implementation.** Today the app talks to Google with
> `package:http` by hand — `lib/core/services/google_translate_service.dart`. That was a
> deliberate choice: CLAUDE.md rule 5 forbids new packages, and `http` is already a dependency.
> This file is the **prompt to hand an agent** (or to follow yourself) if you ever want the same
> feature expressed with Retrofit, the way the parked design on branch
> `chore/architecture-migration` had it. Read `docs/architecture.md` and
> `docs/lightning_icon_rules.md` first; nothing below may change how the app looks or behaves.

## Copy-paste prompt

```text
Move the Google translation layer from hand-written package:http to Retrofit + Dio, without
changing any behaviour or any pixel of UI.

Context to read first:
  docs/architecture.md
  docs/lightning_icon_rules.md            (section "What the popup contains")
  docs/retrofit-translation-prompt.md     (this file — follow the steps in it)
  lib/core/services/google_translate_service.dart
  lib/core/services/translate_response_parser.dart
  lib/core/models/translation_result.dart
  test/google_translate_service_test.dart

CLAUDE.md rule 5 says no new packages without asking, and this task needs three
(dio, retrofit, retrofit_generator). Confirm that with me before touching pubspec.yaml.

Behaviour that must stay identical, verified by the existing tests:
  - one GET to https://translate.googleapis.com/translate_a/single
  - the query carries dt=t & dt=bd & dt=at (three separate dt params, NOT dt[]=t), plus
    client=gtx, sl, tl, dj=0, ie=UTF-8, oe=UTF-8, q
  - the response is a bare JSON array, decoded by TranslateResponseParser unchanged
  - translateWord() keeps the part-of-speech rule exactly: noun > verb > adjective > adverb,
    first ranked candidate inside the chosen group wins, and a noun group with no ranked match
    re-asks Google for "the <word>" before falling back to the group's first entry
  - a failed article lookup is swallowed (it is only a ranking hint)
  - errors reach the screen as TranslationException with the same messages

Work one step at a time and stop if a step cannot be done as written (CLAUDE.md rule 6).
```

## Step 1 — dependencies

```yaml
dependencies:
  dio: ^5.11.1
  retrofit: '>=4.9.0 <4.9.1'   # see the pin note below

dev_dependencies:
  retrofit_generator: 10.0.0   # pinned, not ^
```

The pin is not cosmetic. On the parked branch: `retrofit_generator` 10.0.0 switches exhaustively
over retrofit's `Parser` enum, so `retrofit` 4.9.2 (which adds `DartMappable`) stops the
generator compiling; and a newer generator wants `analyzer` 8, which this Flutter SDK's
`flutter_test` caps below. Keep both pinned and re-check only when the SDK moves.

`http` stays — `VocabPhotoService` still uses it.

## Step 2 — the Dio instance

New file `lib/core/services/translate_dio.dart`:

```dart
/// `ListFormat.multi` is what turns the `dt` list into `dt=t&dt=bd&dt=at`
/// rather than `dt[]=t` — Google ignores the bracketed form and answers
/// without the dictionary block, which silently empties the dots popup.
Dio createTranslateDio() => Dio(
      BaseOptions(
        baseUrl: 'https://translate.googleapis.com',
        connectTimeout: const Duration(seconds: 15),
        sendTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
        listFormat: ListFormat.multi,
      ),
    );
```

Expose it through `lib/core/providers.dart` (`@Riverpod(keepAlive: true) Dio translateDio(Ref)`),
never construct it in a widget — CLAUDE.md rule 2.

## Step 3 — the Retrofit API

New file `lib/core/services/translate_api.dart`:

```dart
@RestApi()
// The generator needs an abstract class with a redirecting factory; a typedef
// would not give it one.
// ignore: one_member_abstracts
abstract class TranslateApi {
  factory TranslateApi(Dio dio, {String? baseUrl}) = _TranslateApi;

  /// The body comes back as text because the endpoint answers with a bare JSON
  /// array; `TranslateResponseParser` decodes it.
  @GET('/translate_a/single')
  @DioResponseType(ResponseType.plain)
  Future<String> single({
    @Query('sl') required String from,
    @Query('tl') required String to,
    @Query('q') required String text,
    @Query('dt') List<String> dt = const ['t', 'bd', 'at'],
    @Query('client') String client = 'gtx',
    @Query('dj') String dj = '0',
    @Query('ie') String inputEncoding = 'UTF-8',
    @Query('oe') String outputEncoding = 'UTF-8',
  });
}
```

Two traps:

- **`@DioResponseType(ResponseType.plain)`** — without it Dio tries to decode a JSON *object* and
  the bare array either fails or arrives as `List<dynamic>` typed as `String`.
- **`dj=0`** — `dj=1` returns a completely different (named-field) JSON shape that
  `TranslateResponseParser` does not understand.

Then `dart run build_runner build --delete-conflicting-outputs` and commit `translate_api.g.dart`.

## Step 4 — the service on top of it

`GoogleTranslateService` keeps its public surface — `translate()`, `translateWord()`,
`TranslationException` — so nothing in `lib/features/` changes. Only its body changes:

```dart
class GoogleTranslateService {
  GoogleTranslateService(this._api);

  final TranslateApi _api;

  Future<TranslationResult> translate(String text, {required String to, String from = 'auto'}) async {
    try {
      final body = await _api.single(from: from, to: to, text: text);
      return TranslateResponseParser.parseBody(body, requestedFrom: from);
    } on DioException catch (e) {
      throw TranslationException(_message(e));   // keep today's message strings
    } catch (e) {
      throw TranslationException('Unexpected response: $e');
    }
  }

  // translateWord() is copied over verbatim — the part-of-speech rule is transport-agnostic.
}
```

Map `DioException` to the same strings the screen shows today, or the snackbars change wording:
`DioExceptionType.connectionTimeout`/`sendTimeout`/`receiveTimeout` →
`'The request timed out, please try again'`; `badResponse` →
`'Request failed (status ${e.response?.statusCode})'`; anything else → `'Network error: $e'`.

Update the provider to `GoogleTranslateService(TranslateApi(ref.watch(translateDioProvider)))`.

`lib/core/models/translation_result.dart` and `lib/core/services/translate_response_parser.dart`
are **not** touched. Do not introduce freezed/json_serializable for them — the parser reads
positional array slots, so a generated DTO buys nothing.

## Step 5 — the tests

`test/google_translate_service_test.dart` must keep passing unchanged *in intent*: same fixtures
(`test/fixtures/translate_*.json`), same nine assertions, including
`uri.queryParametersAll['dt'] == ['t','bd','at']`. Only the fake transport is swapped — replace
`MockClient` with a Dio `HttpClientAdapter` that answers from the fixtures. The parked branch's
version is worth copying as-is:

```
git show chore/architecture-migration:packages/data_remote/test/support/recorded_adapter.dart
git show chore/architecture-migration:packages/data_remote/test/translate_api_test.dart
```

`ResponseBody.fromString` with `content-type: application/json; charset=utf-8` is what keeps the
Cyrillic fixtures intact; with `package:http` the equivalent guard is `utf8.decode(bodyBytes)`.

Keep `tool/smoke_google_translate.dart` (live, run by hand, never in CI) working — it only needs
its constructor call updated.

## Step 6 — before finishing

```
dart run build_runner build --delete-conflicting-outputs
flutter analyze
flutter test
dart run tool/smoke_google_translate.dart      # network; expects Google's 2026-09 answers
grep -rn "Navigator.push\|MaterialPageRoute\|static final .* instance" lib
```

Then update `docs/architecture.md` (§1 folder layout, §3 last bullet) and add a Changelog entry to
`docs/lightning_icon_rules.md` saying the transport changed and the behaviour did not.

## Why it was not done this way

| | `package:http` (today) | Retrofit + Dio |
|---|---|---|
| Packages | none added | +3, one of them pinned hard |
| The `dt` repetition | `Uri.https(..., {'dt': ['t','bd','at']})` | `BaseOptions(listFormat: ListFormat.multi)` — silent wrong answer if forgotten |
| Bare-array response | `utf8.decode(response.bodyBytes)` | needs `@DioResponseType(ResponseType.plain)` |
| Generated code | none | `translate_api.g.dart` to commit and regenerate |
| Payoff | — | typed query params, interceptors (logging, retry) for free — worth it once there are several endpoints |

The Worker API (`VocabPhotoService`) is the other candidate. If both move, Retrofit starts paying
for itself; for one endpoint with one query shape it did not.
