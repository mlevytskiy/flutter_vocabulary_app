import { timedFetch, parseJson, baseUrl } from '../lib/http.mjs';
import { found, failed, skipped } from '../lib/result.mjs';

// Unverified without a key — see task-16 open points.
export const id = 'merriam-webster';
const BASE = baseUrl(id, 'https://www.dictionaryapi.com/api/v3/references/collegiate/json/');

export async function probe(word) {
  const key = process.env.MERRIAM_WEBSTER_KEY;
  if (!key) return skipped('no key');
  const r = await timedFetch(`${BASE}${encodeURIComponent(word)}?key=${encodeURIComponent(key)}`);
  if (!r.ok) return failed(r);
  const entries = parseJson(r.body);
  if (!Array.isArray(entries)) return failed(r, 'unexpected response shape');
  // Unknown word → an array of spelling suggestions (strings).
  if (entries.length && typeof entries[0] === 'string') {
    return found(r, { definitions: [], extra: { suggestions: entries.slice(0, 5) } });
  }

  const definitions = entries.flatMap((e) => e.shortdef ?? []);
  const file = entries.find((e) => e.hwi?.prs?.[0]?.sound?.audio)?.hwi.prs[0].sound.audio;
  return found(r, { definitions, audio: { brE: null, amE: file ? audioUrl(file) : null } });
}

// https://dictionaryapi.com/products/json#sec-2.prs — subdirectory rule for the audio CDN.
function audioUrl(file) {
  const sub = file.startsWith('bix') ? 'bix' : file.startsWith('gg') ? 'gg' : /^[^a-z]/i.test(file) ? 'number' : file[0];
  return `https://media.merriam-webster.com/audio/prons/en/us/mp3/${sub}/${file}.mp3`;
}
