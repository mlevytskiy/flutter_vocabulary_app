// The photo request's prompt and answer rules (`POST /analyze`), kept apart from the route so the
// tests can import them without a Worker (node --test strips the types).

export interface Options {
  context: boolean;
  translation: boolean;
  withDesc: boolean;
  shortifyDefinition: boolean;
  limit?: number;
}

export type ContextSource = "photo" | "ai";

export interface VocabularyWord {
  word: string;
  context?: string;
  /** With `context=true`: "photo" when `context` is quoted from the photo, "ai" when the AI wrote it. */
  context_source?: ContextSource;
  translation?: string;
  description?: string;
}

export function parseOptions(url: URL): Options {
  const limitParam = url.searchParams.get("limit");
  const limitNum = limitParam !== null ? Number(limitParam) : undefined;
  const limit = limitNum !== undefined && Number.isInteger(limitNum) && limitNum > 0 ? limitNum : undefined;

  return {
    context: url.searchParams.get("context") === "true",
    translation: url.searchParams.get("translation") === "true",
    withDesc: url.searchParams.get("with_desc") === "true",
    shortifyDefinition: url.searchParams.get("shortify_definishion") === "true",
    limit,
  };
}

export function buildSystemPrompt(options: Options): string {
  const fields = ['"word": "<original English word or phrase>"'];
  const instructions: string[] = [];

  if (options.context) {
    fields.push('"context": "<the sentence or phrase from the photo where this word appears>"');
    fields.push('"context_source": "<photo or ai>"');
    instructions.push(
      "- context: quote the exact sentence or phrase the word appears in within the photo, and set " +
        'context_source to "photo". Only when the photo has no real sentence with the word (an exercise sheet, ' +
        "a word list, a glossary or a label), write one short natural English sentence yourself that uses the " +
        'word in the meaning it has in the photo, and set context_source to "ai".'
    );
  }
  const shortifyLine = options.shortifyDefinition
    ? " If it is long, shorten it as much as possible without losing its meaning."
    : "";

  if (options.translation) {
    fields.push('"translation": "<Ukrainian translation of the word, fitting its meaning in this context>"');
    instructions.push(
      "- translation: if the photo itself already shows a Ukrainian translation for this word (e.g. a glossary, " +
        "subtitle, or bilingual label), use that exact translation instead of producing your own. Otherwise, " +
        `translate the word to Ukrainian yourself, choosing the sense that fits how it is used in the photo.${shortifyLine}`
    );
  }
  if (options.withDesc) {
    fields.push('"description": "<short English definition of the word, fitting its meaning in this context>"');
    instructions.push(
      "- description: if the photo itself already shows a definition for this word (e.g. a glossary or dictionary " +
        "entry), use that definition, condensed to one sentence if it is longer. Otherwise, write a short (one " +
        `sentence) English definition yourself, matching the meaning the word has in this context.${shortifyLine}`
    );
  }

  const limitLine = options.limit
    ? `Return at most ${options.limit} words or phrases in total. If you find fewer than ${options.limit}, ` +
      `return only the ones you actually found — never pad or invent extra entries to reach the limit. ` +
      `If you find more than ${options.limit} candidates, keep only the ${options.limit} most useful/valuable ones for a learner.`
    : "Return every useful word or phrase you find.";

  return `You are a vocabulary-extraction assistant for a language learner \
whose native language is Ukrainian and who is learning English.

You will be given a photo. Find the useful English words or short phrases visible in it \
(for example on packaging, signs, book pages, or screens). Ignore noise: numbers, single \
letters, barcodes, UI chrome, and words that are not meaningful vocabulary.

${limitLine}

Prefer information that is already visible in the photo (existing translations, definitions, or glossary \
entries) over inventing your own — only generate a translation or definition yourself when the photo doesn't \
already provide one.

For each selected word or phrase, include:
${instructions.join("\n")}

${options.context ? contextAnswerShape(fields) : arrayAnswerShape(fields)}`;
}

function arrayAnswerShape(fields: string[]): string {
  return `Respond with ONLY a strict JSON array, no prose, no markdown code fences, in this exact shape:
[{${fields.join(", ")}}]

Izf no useful vocabulary is visible, respond with an empty array: []`;
}

// With `context=true` the answer is an object: the photo's running text and the words (word-context
// AC-10, ADR-0002).
function contextAnswerShape(fields: string[]): string {
  return `Also give full_text: all the running English text of the photo (its sentences and paragraphs, in reading \
order, as written). Leave out lone words, word lists, exercise numbering and answer blanks. If the photo has no \
running text, full_text is an empty string.

Respond with ONLY a strict JSON object, no prose, no markdown code fences, in this exact shape:
{"full_text": "<the photo's running text, or empty>", "words": [{${fields.join(", ")}}]}

If no useful vocabulary is visible, respond with an empty words list: {"full_text": "", "words": []}`;
}

export function extractJsonArray(text: string): unknown {
  const trimmed = text.trim();
  const fenced = trimmed.match(/```(?:json)?\s*([\s\S]*?)\s*```/i);
  const candidate = fenced ? fenced[1] : trimmed;
  return JSON.parse(candidate);


}

export function isVocabularyWordArray(value: unknown, options: Options): value is VocabularyWord[] {
  return (
    Array.isArray(value) &&
    value.every((item) => {
      if (typeof item !== "object" || item === null) return false;
      const record = item as Record<string, unknown>;
      if (typeof record.word !== "string") return false;
      if (options.context && typeof record.context !== "string") return false;
      if (options.translation && typeof record.translation !== "string") return false;
      if (options.withDesc && typeof record.description !== "string") return false;
      return true;
    })
  );
}

/** The `/analyze` answer's body without `timings`; `full_text` only with `context=true`. */
export interface AnalyzeAnswer {
  words: VocabularyWord[];
  full_text?: string;
}

/**
 * Reads the model's text into the route's answer, or null when it does not match the asked-for shape.
 * With `context=true` the model answers `{full_text, words}`; an answer without the new fields (a bare
 * array, no `full_text`, no `context_source`) is still accepted: `full_text` becomes "" and a missing or
 * unknown `context_source` becomes "photo", as every context was a quote before (ADR-0002).
 * Throws when the text is not JSON.
 */
export function parseAnalyzeAnswer(text: string, options: Options): AnalyzeAnswer | null {
  const parsed = extractJsonArray(text);
  if (!options.context) {
    return isVocabularyWordArray(parsed, options) ? { words: parsed } : null;
  }
  let words: unknown = parsed;
  let fullText: unknown = "";
  if (!Array.isArray(parsed)) {
    if (typeof parsed !== "object" || parsed === null) return null;
    const record = parsed as Record<string, unknown>;
    words = record.words;
    fullText = record.full_text ?? "";
  }
  if (!isVocabularyWordArray(words, options)) return null;
  return {
    full_text: typeof fullText === "string" ? fullText.trim() : "",
    words: words.map((word) => ({ ...word, context_source: word.context_source === "ai" ? "ai" : "photo" })),
  };
}
