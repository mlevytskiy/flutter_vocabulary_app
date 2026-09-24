import { timedFetch, parseJson, baseUrl } from '../lib/http.mjs';
import { found, failed, skipped } from '../lib/result.mjs';

// Unverified without a key. Sandbox keys only answer for words starting with "a".
export const id = 'oxford';
const BASE = baseUrl(id, 'https://od-api.oxforddictionaries.com/api/v2/entries/en-gb/');

export async function probe(word) {
  const appId = process.env.OXFORD_APP_ID;
  const appKey = process.env.OXFORD_APP_KEY;
  if (!appId || !appKey) return skipped('no key');
  const r = await timedFetch(`${BASE}${encodeURIComponent(word.toLowerCase())}?strictMatch=false`, {
    headers: { app_id: appId, app_key: appKey },
  });
  if (!r.ok) return failed(r, parseJson(r.body)?.error ?? r.error);
  const data = parseJson(r.body);
  const lexical = (data?.results ?? []).flatMap((res) => res.lexicalEntries ?? []);
  const entries = lexical.flatMap((l) => l.entries ?? []);

  const senses = entries.flatMap((e) => e.senses ?? []);
  const definitions = senses.flatMap((s) => s.definitions ?? []);
  const prons = [...lexical, ...entries].flatMap((x) => x.pronunciations ?? []);
  const byDialect = (re) => prons.find((p) => p.audioFile && (p.dialects ?? []).some((d) => re.test(d)))?.audioFile ?? null;
  return found(r, { definitions, audio: { brE: byDialect(/british/i), amE: byDialect(/american/i) } });
}
