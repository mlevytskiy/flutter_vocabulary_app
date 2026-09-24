// Shared by Cambridge and Collins, which both serve the same "Dictionary API v1"
// (search/first, `accessKey` header, entryContent as HTML). Lives in lib/ because it is not a provider itself.
import { timedFetch, parseJson } from './http.mjs';
import { stripHtml, classifyAudio } from './text.mjs';
import { found, failed } from './result.mjs';

export async function probeIdm({ base, dictCode, key, word }) {
  const url = `${base}/api/v1/dictionaries/${dictCode}/search/first/?q=${encodeURIComponent(word)}&format=html`;
  const r = await timedFetch(url, { headers: { accessKey: key, Accept: 'application/json' } });
  if (!r.ok) return failed(r, parseJson(r.body)?.errorMessage ?? r.error);
  const html = parseJson(r.body)?.entryContent;
  if (typeof html !== 'string') return failed(r, 'unexpected response shape');

  // Unverified markup guesses; task-18 checks them against a real response.
  const definitions = [...html.matchAll(/<span[^>]*class="[^"]*\bdef\b[^"]*"[^>]*>([\s\S]*?)<\/span>/g)]
    .map((m) => stripHtml(m[1]))
    .filter(Boolean);
  const urls = [...html.matchAll(/(?:data-src-mp3|href|src)="([^"]+\.mp3)"/g)].map((m) => m[1]);
  const { audio, other } = classifyAudio(urls);
  return found(r, { definitions, audio, otherAudio: other });
}
