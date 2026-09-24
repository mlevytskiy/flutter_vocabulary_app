import { timedFetch, parseJson, baseUrl } from '../lib/http.mjs';
import { found, failed, skipped } from '../lib/result.mjs';

// Unverified without a key. One definition string, no audio.
export const id = 'api-ninjas';
const BASE = baseUrl(id, 'https://api.api-ninjas.com/v1/dictionary');

export async function probe(word) {
  const key = process.env.API_NINJAS_KEY;
  if (!key) return skipped('no key');
  const r = await timedFetch(`${BASE}?word=${encodeURIComponent(word)}`, { headers: { 'X-Api-Key': key } });
  if (!r.ok) return failed(r, parseJson(r.body)?.error ?? r.error);
  const data = parseJson(r.body);
  const definitions = data?.valid && data.definition ? [data.definition.trim()] : [];
  return found(r, { definitions });
}
