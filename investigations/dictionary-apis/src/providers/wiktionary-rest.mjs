import { timedFetch, parseJson, baseUrl } from '../lib/http.mjs';
import { stripHtml } from '../lib/text.mjs';
import { found, failed } from '../lib/result.mjs';

export const id = 'wiktionary-rest';
const BASE = baseUrl(id, 'https://en.wiktionary.org/api/rest_v1/page/definition/');

// The definition endpoint carries no audio; English senses only (`en`).
export async function probe(word) {
  const r = await timedFetch(BASE + encodeURIComponent(word.replace(/ /g, '_')));
  if (!r.ok) return failed(r, parseJson(r.body)?.title ?? r.error);
  const data = parseJson(r.body);
  if (!data || typeof data !== 'object') return failed(r, 'unexpected response shape');

  const definitions = (data.en ?? [])
    .flatMap((pos) => (pos.definitions ?? []).map((d) => stripHtml(d.definition)))
    .filter(Boolean);
  return found(r, { definitions });
}
