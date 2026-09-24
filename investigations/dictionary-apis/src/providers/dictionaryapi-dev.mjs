import { timedFetch, parseJson, baseUrl } from '../lib/http.mjs';
import { classifyAudio } from '../lib/text.mjs';
import { found, failed } from '../lib/result.mjs';

export const id = 'dictionaryapi-dev';
const BASE = baseUrl(id, 'https://api.dictionaryapi.dev/api/v2/entries/en/');

export async function probe(word) {
  const r = await timedFetch(BASE + encodeURIComponent(word));
  if (!r.ok) return failed(r, parseJson(r.body)?.title ?? r.error);
  const entries = parseJson(r.body);
  if (!Array.isArray(entries)) return failed(r, 'unexpected response shape');

  const definitions = entries.flatMap((e) =>
    (e.meanings ?? []).flatMap((m) => (m.definitions ?? []).map((d) => d.definition).filter(Boolean)),
  );
  const urls = entries.flatMap((e) => (e.phonetics ?? []).map((p) => p.audio));
  const { audio, other } = classifyAudio(urls);
  return found(r, { definitions, audio, otherAudio: other });
}
