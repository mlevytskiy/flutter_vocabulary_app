import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/azure_config.dart';

/// Azure Translator's global endpoint. Works with region-scoped and
/// multi-service ("AI Foundry") resources alike, as long as the
/// `Ocp-Apim-Subscription-Region` header carries the resource's region —
/// there's no separate regional hostname to worry about.
const _dictionaryLookupEndpoint =
    'https://api.cognitive.microsofttranslator.com/dictionary/lookup'
    '?api-version=3.0&from=en&to=uk';

/// Returns distinct alternative Ukrainian translations for [word] using
/// Azure Translator's Dictionary Lookup API. Returns an empty list on any
/// error, timeout, or "no additional senses found" — callers should treat
/// that as "0 alternatives".
///
/// SUPERSEDED: no longer called anywhere in the app. Google's combined
/// `dt=t`+`dt=bd` endpoint (see google_translate_dictionary_service.dart's
/// `fetchTranslationWithDictionary`) gets equivalent "alternative senses"
/// data for free, in the very same request that already fetches the
/// primary translation — making this separate, paid Azure call
/// unnecessary. Left in place only for reference/potential future use
/// (e.g. if the undocumented Google endpoint ever becomes unreliable
/// enough to warrant switching back).
Future<List<String>> fetchAlternativeTranslations(
  String word, {
  Duration timeout = const Duration(seconds: 5),
}) async {
  final trimmed = word.trim();
  if (trimmed.isEmpty) return [];

  try {
    final response = await http
        .post(
          Uri.parse(_dictionaryLookupEndpoint),
          headers: {
            'Ocp-Apim-Subscription-Key': AzureConfig.translatorKey,
            'Ocp-Apim-Subscription-Region': AzureConfig.translatorRegion,
            'Content-Type': 'application/json',
          },
          body: jsonEncode([
            {'Text': trimmed}
          ]),
        )
        .timeout(timeout);

    if (response.statusCode != 200) return [];

    final decoded = jsonDecode(response.body);
    // One entry per input word -- we only ever send one.
    if (decoded is! List || decoded.isEmpty) return [];

    final entry = decoded.first;
    final translations = entry is Map ? entry['translations'] : null;
    if (translations is! List) return [];

    // Case/whitespace-insensitive de-dupe, preserving first-seen order
    // (the API already returns entries ordered by confidence).
    final seenLowercase = <String>{};
    final results = <String>[];
    for (final candidate in translations) {
      if (candidate is! Map) continue;
      final target = (candidate['normalizedTarget'] ?? candidate['displayTarget'])
          ?.toString()
          .trim();
      if (target == null || target.isEmpty) continue;
      if (seenLowercase.add(target.toLowerCase())) {
        results.add(target);
      }
    }
    return results;
  } catch (_) {
    // Network error, timeout, malformed JSON, etc. -- this is a
    // "nice to have" enrichment call, so any failure quietly degrades to
    // "no alternatives" rather than surfacing an error to the user.
    return [];
  }
}

// --- Azure OpenAI translation cleanup (live once configured) ---------------
//
// `AzureConfig.openAiEndpoint`/`openAiDeploymentName`/`openAiApiKey` are
// still empty placeholders (see azure_config.dart) -- an Azure OpenAI model
// deployment hasn't been created yet. Until then, `selectAndNormalizeTranslations`
// below quietly uses its non-AI heuristic fallback instead of attempting a
// network call that's guaranteed to fail authentication (see
// `_isAzureOpenAiConfigured`). The moment real credentials are filled in,
// its AI path activates automatically -- word_input_screen.dart already
// calls it unconditionally, no code changes needed there.
//
// `normalizeToLemmaForm` remains available too, for pure 1:1 normalization
// of an already-small, already-clean candidate list (e.g. if the app ever
// goes back to Azure Translator's Dictionary Lookup as its alternatives
// source). See that function's doc comment for the exact Azure AI Foundry
// setup steps required to configure either one.

/// The chat-completions route on Azure AI Foundry's unified OpenAI v1 API
/// (GA since August 2025). Uses implicit versioning -- no `api-version`
/// query parameter needed. Source: Microsoft Learn, "Create chat
/// completion" (learn.microsoft.com/en-us/azure/foundry/openai/latest) and
/// "Use chat completions with Foundry Models"
/// (learn.microsoft.com/en-us/azure/ai-foundry/foundry-models/how-to/use-chat-completions),
/// both accessed 2026.
const _chatCompletionsPath = '/openai/v1/chat/completions';

/// Whether Azure OpenAI has actually been configured -- i.e. AzureConfig's
/// `openAi*` fields are no longer empty placeholders (see
/// azure_config.dart). Both [normalizeToLemmaForm] and
/// [selectAndNormalizeTranslations] check this before attempting a network
/// call, since a request against empty/placeholder credentials is
/// guaranteed to fail authentication -- there's no point making it.
bool get _isAzureOpenAiConfigured =>
    AzureConfig.openAiEndpoint.isNotEmpty &&
    AzureConfig.openAiDeploymentName.isNotEmpty &&
    AzureConfig.openAiApiKey.isNotEmpty;

/// Takes the raw (possibly inflected) candidate translations already
/// returned by [fetchAlternativeTranslations], and normalizes each to its
/// base dictionary/lemma form (nominative singular for nouns/adjectives,
/// infinitive for verbs) using Azure OpenAI.
///
/// This is deliberately a *normalization* pass on top of already-real,
/// dictionary-sourced words, rather than asking the model to generate
/// translations from scratch: normalizing a known-real word's grammatical
/// form is a much more constrained task than free-form generation, so it
/// carries far less hallucination risk (worst case, the model fails to
/// normalize something and the original -- still real, just inflected --
/// word is used as a fallback).
///
/// Falls back to returning [candidates] unchanged on any error, timeout, or
/// suspicious response (wrong item count, empty strings, unparseable JSON).
/// Never throws, and never returns fewer/different words than went in --
/// this function should never make results *worse* than not calling it.
///
/// ## Azure AI Foundry setup required (not yet done -- see AzureConfig)
/// 1. In the Azure AI Foundry portal (ai.azure.com), open the same resource
///    used for Translator (or create/use an "Azure AI Foundry" /
///    "Azure OpenAI" resource).
/// 2. Under "Deployments", create a new deployment of a chat model --
///    `gpt-4o-mini` is a good, cheap default for this task.
/// 3. Note the **deployment name** you gave it (not necessarily the same as
///    the underlying model name) -> `AzureConfig.openAiDeploymentName`.
/// 4. Under "Keys and Endpoint" for that resource, copy the **endpoint**
///    (format: `https://YOUR-RESOURCE-NAME.openai.azure.com`, no trailing
///    path) -> `AzureConfig.openAiEndpoint`.
/// 5. Copy a key from the same page -> `AzureConfig.openAiApiKey`. If this
///    is confirmed to be the same unified multi-service resource as
///    Translator, this may be identical to `translatorKey` -- check the
///    portal page itself rather than assuming.
Future<List<String>> normalizeToLemmaForm(
  List<String> candidates,
  String sourceWord, {
  Duration timeout = const Duration(seconds: 8),
}) async {
  if (candidates.isEmpty) return candidates;
  if (!_isAzureOpenAiConfigured) return candidates;

  try {
    final response = await http
        .post(
          Uri.parse('${AzureConfig.openAiEndpoint}$_chatCompletionsPath'),
          headers: {
            'api-key': AzureConfig.openAiApiKey,
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'model': AzureConfig.openAiDeploymentName,
            'messages': [
              {
                'role': 'system',
                'content': 'You are a precise Ukrainian lexicographer. You '
                    'only normalize existing words to their dictionary base '
                    'form; you never invent, translate, or substitute '
                    'different words.'
              },
              {'role': 'user', 'content': _buildLemmaPrompt(sourceWord, candidates)},
            ],
            'response_format': {'type': 'json_object'},
            'temperature': 0,
          }),
        )
        .timeout(timeout);

    if (response.statusCode != 200) return candidates;

    return parseNormalizedLemmaResponse(response.body, candidates);
  } catch (_) {
    // Network error, timeout, malformed JSON, etc. -- fall back to the
    // original (still real, just possibly inflected) candidates rather
    // than losing them or surfacing an error to the user.
    return candidates;
  }
}

String _buildLemmaPrompt(String sourceWord, List<String> candidates) {
  return 'For the English word "$sourceWord", here are some Ukrainian '
      'translation candidates that may be in inflected grammatical forms: '
      '${jsonEncode(candidates)}. Return each one normalized to its base '
      'dictionary form (nominative singular for nouns/adjectives, '
      'infinitive for verbs), preserving the same order and count. '
      'Respond with JSON only, in the shape {"normalized": ["...", "..."]}.';
}

/// Parses an Azure OpenAI chat-completions response body and extracts the
/// normalized word list, applying [normalizeToLemmaForm]'s
/// validation/fallback rules. Exposed as a top-level function (rather than
/// kept private inside `normalizeToLemmaForm`) specifically so it can be
/// unit tested directly against sample response bodies without needing a
/// live network call or HTTP mocking.
List<String> parseNormalizedLemmaResponse(
  String responseBody,
  List<String> candidates,
) {
  try {
    final decoded = jsonDecode(responseBody);
    final choices = decoded is Map ? decoded['choices'] : null;
    if (choices is! List || choices.isEmpty) return candidates;

    final firstChoice = choices.first;
    final message = firstChoice is Map ? firstChoice['message'] : null;
    final content = message is Map ? message['content'] : null;
    if (content is! String) return candidates;

    final parsedContent = jsonDecode(content);
    final normalizedRaw =
        parsedContent is Map ? parsedContent['normalized'] : null;
    if (normalizedRaw is! List) return candidates;

    final normalized =
        normalizedRaw.map((item) => item?.toString().trim() ?? '').toList();

    // Sanity checks: must match the input count exactly and contain no
    // empty strings -- anything else is treated as an untrustworthy
    // response, and the original (still-real) candidates are kept instead.
    if (normalized.length != candidates.length ||
        normalized.any((word) => word.isEmpty)) {
      return candidates;
    }

    return normalized;
  } catch (_) {
    return candidates;
  }
}

// --- Selection + normalization for large/messy candidate lists -------------
//
// Google Translate's `dt=bd` dictionary data (see
// google_translate_dictionary_service.dart) is bigger and messier than
// Azure Translator's Dictionary Lookup was: for a rich word like "bank" it
// can flatten out to ~30 entries across parts of speech, mixing inflected
// forms, multi-word phrases (e.g. "класти гроші в банк"), and near-
// duplicate senses. selectAndNormalizeTranslations below both normalizes
// AND intelligently trims that down to a handful of distinct senses,
// unlike normalizeToLemmaForm above (which preserves the input count 1:1
// and expects an already-small, already-clean list).

/// Cleans up a raw, potentially large and messy list of candidate
/// translations -- e.g. Google Translate's flattened `dt=bd` dictionary
/// list -- down to at most [maxResults] distinct, base-form translations.
///
/// Safe to call unconditionally regardless of whether Azure OpenAI has
/// been configured yet:
/// - If `AzureConfig.openAiEndpoint`/`openAiDeploymentName`/`openAiApiKey`
///   are still empty placeholders, this skips the network call entirely
///   (see [_isAzureOpenAiConfigured]) and goes straight to
///   [heuristicSelectAndNormalize].
/// - If they ARE configured, this asks Azure OpenAI to both normalize each
///   selected candidate to its base dictionary form AND intelligently
///   choose the best [maxResults] *distinct* senses -- preferring single
///   words over multi-word phrases and common meanings over obscure ones
///   -- rather than just truncating the raw list.
/// - On any AI error, timeout, or unparseable/empty response, this falls
///   back to the same non-AI heuristic. This function should never return
///   something worse than (or throw instead of) that heuristic.
///
/// The moment real Azure OpenAI credentials are filled in to AzureConfig,
/// this function's AI path activates automatically -- word_input_screen.dart
/// already calls this unconditionally, so no caller-side changes are
/// needed to "turn on" the AI cleanup pass later.
Future<List<String>> selectAndNormalizeTranslations(
  List<String> candidates,
  String sourceWord, {
  int maxResults = 5,
  Duration timeout = const Duration(seconds: 8),
}) async {
  if (candidates.isEmpty) return candidates;
  if (!_isAzureOpenAiConfigured) {
    return heuristicSelectAndNormalize(candidates, maxResults);
  }

  try {
    final response = await http
        .post(
          Uri.parse('${AzureConfig.openAiEndpoint}$_chatCompletionsPath'),
          headers: {
            'api-key': AzureConfig.openAiApiKey,
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'model': AzureConfig.openAiDeploymentName,
            'messages': [
              {
                'role': 'system',
                'content': 'You are a precise Ukrainian lexicographer. You '
                    'only select and normalize words already present in '
                    'the given list; you never invent or substitute '
                    'different words.'
              },
              {
                'role': 'user',
                'content':
                    _buildSelectionPrompt(sourceWord, candidates, maxResults),
              },
            ],
            'response_format': {'type': 'json_object'},
            'temperature': 0,
          }),
        )
        .timeout(timeout);

    if (response.statusCode != 200) {
      return heuristicSelectAndNormalize(candidates, maxResults);
    }

    return parseSelectedTranslationsResponse(response.body, maxResults) ??
        heuristicSelectAndNormalize(candidates, maxResults);
  } catch (_) {
    // Network error, timeout, malformed JSON, etc. -- fall back to the
    // simple heuristic rather than losing the candidate list entirely.
    return heuristicSelectAndNormalize(candidates, maxResults);
  }
}

String _buildSelectionPrompt(
  String sourceWord,
  List<String> candidates,
  int maxResults,
) {
  return 'For the English word "$sourceWord", here is a raw list of '
      'Ukrainian translation candidates gathered from a dictionary lookup. '
      'It may contain inflected grammatical forms, multi-word phrases, '
      'and near-duplicate entries across different parts of speech: '
      '${jsonEncode(candidates)}. From this list, select up to $maxResults '
      'entries that best represent distinct, common meanings of the word, '
      'each normalized to its base dictionary form (nominative singular '
      'for nouns/adjectives, infinitive for verbs). Prefer single words '
      'over multi-word phrases when a single-word sense is available, '
      'avoid near-duplicate meanings, and only use words already present '
      'in the given list (after normalizing their form) -- do not invent '
      'new ones. Respond with JSON only, in the shape '
      '{"selected": ["...", "..."]}.';
}

/// Parses an Azure OpenAI chat-completions response body for
/// [selectAndNormalizeTranslations]. Returns the deduped, capped selection,
/// or `null` if the response is missing, malformed, or empty/all-junk --
/// in which case the caller should fall back to
/// [heuristicSelectAndNormalize]. Exposed as a top-level function (rather
/// than kept private) so it can be unit tested directly against sample
/// response bodies without a live network call.
List<String>? parseSelectedTranslationsResponse(
  String responseBody,
  int maxResults,
) {
  try {
    final decoded = jsonDecode(responseBody);
    final choices = decoded is Map ? decoded['choices'] : null;
    if (choices is! List || choices.isEmpty) return null;

    final firstChoice = choices.first;
    final message = firstChoice is Map ? firstChoice['message'] : null;
    final content = message is Map ? message['content'] : null;
    if (content is! String) return null;

    final parsedContent = jsonDecode(content);
    final selectedRaw = parsedContent is Map ? parsedContent['selected'] : null;
    if (selectedRaw is! List) return null;

    final seenLowercase = <String>{};
    final selected = <String>[];
    for (final item in selectedRaw) {
      final word = item?.toString().trim();
      if (word == null || word.isEmpty) continue;
      if (seenLowercase.add(word.toLowerCase())) {
        selected.add(word);
      }
    }

    // An empty/all-junk result is untrustworthy -- fall back rather than
    // showing the user an empty popup when the raw list clearly had
    // usable candidates to choose from.
    if (selected.isEmpty) return null;

    return selected.length > maxResults
        ? selected.sublist(0, maxResults)
        : selected;
  } catch (_) {
    return null;
  }
}

/// Non-AI fallback selection: dedupes [candidates] case/whitespace-
/// insensitively, prefers single-word entries over multi-word phrases
/// (a lone word reads better as a swappable "alternative translation"
/// than a full phrase), and caps the result at [maxResults]. This is what
/// every user sees today, before any Azure OpenAI credentials exist, and
/// is also the safety net whenever the AI call itself fails.
///
/// Exposed as a top-level function (rather than kept private) so it can be
/// unit tested directly and deterministically, independent of whatever
/// AzureConfig's `openAi*` values happen to be set to in the environment
/// the tests run in.
List<String> heuristicSelectAndNormalize(
  List<String> candidates,
  int maxResults,
) {
  final seenLowercase = <String>{};
  final singleWords = <String>[];
  final phrases = <String>[];
  for (final candidate in candidates) {
    final trimmed = candidate.trim();
    if (trimmed.isEmpty) continue;
    if (!seenLowercase.add(trimmed.toLowerCase())) continue;
    (trimmed.contains(' ') ? phrases : singleWords).add(trimmed);
  }
  return [...singleWords, ...phrases].take(maxResults).toList();
}
