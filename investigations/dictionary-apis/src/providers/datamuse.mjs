import { timedFetch, parseJson, baseUrl } from '../lib/http.mjs';
import { found, failed } from '../lib/result.mjs';

export const id = 'datamuse';
const BASE = baseUrl(id, 'https://api.datamuse.com/words');

// `sp` = exact spelling; md=dr adds definitions and ARPAbet pronunciation. No audio.
export async function probe(word) {
  const r = await timedFetch(`${BASE}?sp=${encodeURIComponent(word)}&md=dr&max=1`);
  if (!r.ok) return failed(r);
  const items = parseJson(r.body);
  if (!Array.isArray(items)) return failed(r, 'unexpected response shape');

  const hit = items.find((i) => i.word?.toLowerCase() === word.toLowerCase());
  // defs look like "adj\tHaving a firm hold" — drop the part-of-speech prefix.
  const definitions = (hit?.defs ?? []).map((d) => d.split('\t').slice(1).join('\t').trim()).filter(Boolean);
  const arpabet = hit?.tags?.find((t) => t.startsWith('pron:'))?.slice(5).trim();
  return found(r, { definitions, extra: arpabet ? { arpabet } : undefined });
}
