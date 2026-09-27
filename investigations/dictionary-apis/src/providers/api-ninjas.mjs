import { timedFetch, parseJson, baseUrl } from '../lib/http.mjs';
import { found, failed, skipped } from '../lib/result.mjs';

// One definition string with the senses numbered inline ("1. … 2. …"); no audio.
export const id = 'api-ninjas';
const BASE = baseUrl(id, 'https://api.api-ninjas.com/v1/dictionary');

export async function probe(word) {
  const key = process.env.API_NINJAS_KEY;
  if (!key) return skipped('no key');
  const r = await timedFetch(`${BASE}?word=${encodeURIComponent(word)}`, { headers: { 'X-Api-Key': key } });
  if (!r.ok) return failed(r, parseJson(r.body)?.error ?? r.error);
  const data = parseJson(r.body);
  const text = data?.valid && data.definition ? data.definition.trim() : '';
  const definitions = text ? text.split(/(?:^|\s)\d+\.\s+/).map((d) => d.trim()).filter(Boolean) : [];
  return found(r, { definitions });
}
