import { timedFetch, parseJson, baseUrl } from '../lib/http.mjs';
import { found, failed, skipped } from '../lib/result.mjs';

// Pronunciation is IPA text only, no audio.
export const id = 'wordsapi';
const HOST = 'wordsapiv1.p.rapidapi.com';
const BASE = baseUrl(id, `https://${HOST}/words/`);

export async function probe(word) {
  const key = process.env.WORDSAPI_KEY;
  if (!key) return skipped('no key');
  const r = await timedFetch(BASE + encodeURIComponent(word), {
    headers: { 'X-RapidAPI-Key': key, 'X-RapidAPI-Host': HOST },
  });
  if (!r.ok) return failed(r, parseJson(r.body)?.message ?? r.error);
  const data = parseJson(r.body);
  const definitions = (data?.results ?? []).map((x) => x.definition).filter(Boolean);
  const ipa = data?.pronunciation?.all ?? data?.pronunciation;
  return found(r, { definitions, extra: typeof ipa === 'string' ? { ipa } : undefined });
}
