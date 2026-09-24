// Asks every probeable, non-excluded provider for each fixture word and writes
// out/results.json, keyed by provider id then word id.
//
//   npm run probe              # cold: first call to each host pays DNS + TLS
//   npm run probe -- --warm    # one discarded call per provider (and its audio host) first
//
// Runs sequentially on purpose, so calls never compete and timings stay comparable.

import { readFile, writeFile, mkdir } from 'node:fs/promises';
import { existsSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { timedFetch } from './lib/http.mjs';

const root = fileURLToPath(new URL('..', import.meta.url));
const warm = process.argv.includes('--warm');
const WARM_WORD = 'hello';

if (existsSync(`${root}.env`)) process.loadEnvFile(`${root}.env`);

const words = JSON.parse(await readFile(`${root}data/words.json`, 'utf8'));
const { providers } = JSON.parse(await readFile(`${root}data/providers.json`, 'utf8'));
const targets = providers.filter((p) => p.probeable && !p.excluded);

const results = {};
const providerStatus = {};

for (const provider of targets) {
  results[provider.id] = {};
  let adapter;
  try {
    adapter = await import(`./providers/${provider.id}.mjs`);
  } catch (e) {
    providerStatus[provider.id] = `no adapter: ${e.message}`;
    for (const w of words) results[provider.id][w.id] = { word: w.word, ms: 0, status: 'no-adapter', error: e.message };
    continue;
  }

  if (warm) await runOne(adapter, WARM_WORD); // result discarded

  let skippedReason = null;
  for (const w of words) {
    const entry = await runOne(adapter, w.word);
    results[provider.id][w.id] = { word: w.word, ...entry };
    if (entry.skipped) skippedReason = entry.skipped;
  }
  providerStatus[provider.id] = skippedReason ? `skipped: ${skippedReason}` : 'probed';
  log(provider.id, results[provider.id]);
}

const output = {
  meta: {
    generatedAt: new Date().toISOString(),
    node: process.version,
    warm,
    timing:
      'ms = wall-clock around the awaited fetch, including reading the body. ' +
      'Without --warm the first call to each host also pays DNS + TLS setup. ' +
      'Audio ms is a separate GET of the audio URL, so the definition ms stays clean. ' +
      'Skipped rows carry ms: 0 and status "skipped" — no request was made.',
    words: words.map(({ id, word }) => ({ id, word })),
  },
  providerStatus,
  results,
};

await mkdir(`${root}out`, { recursive: true });
await writeFile(`${root}out/results.json`, JSON.stringify(output, null, 2) + '\n');
console.log(`\nwrote out/results.json (${targets.length} providers × ${words.length} words, warm=${warm})`);

async function runOne(adapter, word) {
  const t0 = performance.now();
  let res;
  try {
    res = await adapter.probe(word);
  } catch (e) {
    // An adapter bug is a row too; it never aborts the run.
    return { ms: Math.round(performance.now() - t0), status: 'adapter-error', error: String(e?.stack ?? e) };
  }
  if (res.skipped) return { ms: 0, status: 'skipped', skipped: res.skipped };
  if (res.audio) {
    res.audio = { brE: await fetchAudio(res.audio.brE), amE: await fetchAudio(res.audio.amE) };
  }
  return res;
}

async function fetchAudio(url) {
  if (!url) return null;
  const r = await timedFetch(url, { binary: true });
  const out = { url, ms: r.ms, status: r.status };
  if (r.ok) out.bytes = r.body.byteLength;
  else out.error = r.error;
  return out;
}

function log(id, rows) {
  console.log(`\n${id}`);
  for (const [wid, r] of Object.entries(rows)) {
    const what = r.skipped
      ? `skipped (${r.skipped})`
      : r.definitions
        ? `${r.senseCount} senses  brE:${r.audio?.brE ? r.audio.brE.ms + 'ms' : '—'}  amE:${r.audio?.amE ? r.audio.amE.ms + 'ms' : '—'}`
        : `${r.status} ${r.error ?? ''}`;
    console.log(`  ${wid} ${r.word.padEnd(20)} ${String(r.ms).padStart(8)} ms  ${what}`);
  }
}
