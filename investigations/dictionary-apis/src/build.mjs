// Renders data/providers.json + out/results.json into a self-contained index.html.
//
//   npm run build    # writes index.html
//   npm run serve    # http://localhost:8000
//
// Every third-party string is stripped of markup and escaped; nothing is injected raw.
// With out/results.json missing, the results section says "run npm run probe" instead.

import { readFile, writeFile } from 'node:fs/promises';
import { existsSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { stripHtml } from './lib/text.mjs';

const root = fileURLToPath(new URL('..', import.meta.url));
const template = await readFile(`${root}src/page/template.html`, 'utf8');
const data = JSON.parse(await readFile(`${root}data/providers.json`, 'utf8'));
const resultsPath = `${root}out/results.json`;
const run = existsSync(resultsPath) ? JSON.parse(await readFile(resultsPath, 'utf8')) : null;

const providers = data.providers;
const live = providers.filter((p) => !p.excluded);
const probeable = live.filter((p) => p.probeable);
const rejected = providers.filter((p) => p.excluded);
const manualIds = new Set((data.registrationHelp ?? []).map((r) => r.id));

const html = template
  .replace('<!--META-->', renderMeta())
  .replace('<!--ISSUES-->', renderIssues())
  .replace('<!--DESCRIPTIONS-->', live.map(renderCard).join('\n'))
  .replace('<!--COST-->', renderCost())
  .replace('<!--RESULTS-->', run ? probeable.map(renderProvider).join('\n') : noResults())
  .replace('<!--REJECTED-->', renderRejected());

await writeFile(`${root}index.html`, html);
console.log(`wrote index.html (${run ? 'with' : 'without'} probe results)`);

// ---------------------------------------------------------------- sections

function renderMeta() {
  const parts = [`Shortlist as of ${esc(data.asOf)}`];
  if (run) {
    parts.push(`probe run ${esc(run.meta.generatedAt.replace('T', ' ').slice(0, 16))} UTC`);
    parts.push(run.meta.warm ? 'hosts warmed first (no DNS/TLS in timings)' : 'cold run (first call per host includes DNS/TLS)');
    parts.push('one machine, one day: indicative, not a benchmark');
  }
  return parts.join(' · ');
}

function renderIssues() {
  if (!run) return '';
  const issues = probeable.flatMap((p) => {
    const rows = Object.values(run.results[p.id] ?? {});
    if (!rows.length || rows.every((r) => r.status === 'skipped')) return [];
    const failed = rows.filter((r) => !r.definitions);
    if (failed.length !== rows.length) return [];
    const codes = [...new Set(failed.map((r) => r.status))].join(', ');
    return [`<li><b>${esc(p.name)}</b>: every word failed (${esc(codes)}), median ${fmtMs(median(failed.map((r) => r.ms)))} per request.</li>`];
  });
  return issues.length ? `<div class="callout"><b>Sources with issues</b><ul>${issues.join('')}</ul></div>` : '';
}

function renderCard(p) {
  const docs = p.docsUrl ? ` · <a href="${attr(p.docsUrl)}" rel="noopener">docs</a>` : '';
  const note = p.note ? `<p class="note">${esc(p.note)}</p>` : '';
  return `<div class="card"><h3>${esc(p.name)}</h3><p>${regBadge(p)}${docs}</p><p>${esc(p.description)}</p>${note}</div>`;
}

function renderCost() {
  const rows = live
    .map(
      (p) =>
        `<tr><td>${esc(p.name)}</td><td>${esc(p.freeTier)}</td><td>${esc(p.paid)}</td>` +
        `<td class="c">${p.keyRequired ? 'yes' : 'no'}</td><td>${regBadge(p)}</td>` +
        `<td class="c">${esc(p.audio.brE)}</td><td class="c">${esc(p.audio.amE)}</td></tr>`,
    )
    .join('\n');
  return (
    '<table><thead><tr><th>Provider</th><th>Free tier</th><th>Paid</th><th class="c">Key</th>' +
    '<th>Registration</th><th class="c">🔊🇬🇧</th><th class="c">🔊🇺🇸</th></tr></thead>' +
    `<tbody>${rows}</tbody></table>`
  );
}

function renderProvider(p) {
  const rows = run.results[p.id];
  const words = run.meta.words;
  if (!rows) {
    return `<details class="provider"><summary>${esc(p.name)}<span class="sum">not in this probe run</span></summary></details>`;
  }
  const list = words.map((w) => rows[w.id]).filter(Boolean);
  const body = words.map((w) => (rows[w.id] ? renderRow(p, rows[w.id]) : '')).join('\n');
  const open = list.some((r) => r.definitions) ? ' open' : '';
  return (
    `<details class="provider"${open}><summary>${esc(p.name)}<span class="sum">${esc(summarise(list))}</span></summary>` +
    '<div class="table-wrap"><table><colgroup><col class="w"><col><col class="a"><col class="a"><col class="t"><col class="t"><col class="t"></colgroup>' +
    '<thead><tr><th>Word</th><th>Definition</th><th class="c" title="British pronunciation (BrE)">🔊🇬🇧</th>' +
    '<th class="c" title="American pronunciation (AmE)">🔊🇺🇸</th><th class="num" title="BrE audio fetch time, ms">🇬🇧 t</th>' +
    '<th class="num" title="AmE audio fetch time, ms">🇺🇸 t</th><th class="num" title="Definition request time, ms">def t</th></tr></thead>' +
    `<tbody>${body}</tbody></table></div></details>`
  );
}

function renderRow(p, r) {
  const word = `<td class="word">${esc(r.word)}</td>`;
  if (r.status === 'skipped') {
    return `<tr>${word}<td colspan="6" class="skip">skipped: ${esc(r.skipped)} (no request made)</td></tr>`;
  }
  if (!r.definitions) {
    const cells = `<td class="err">${esc(String(r.status))}${r.error ? ` · ${esc(clip(r.error, 160))}` : ''}</td>`;
    const gone = '<td class="c dash">—</td>'.repeat(2) + '<td class="num dash">—</td>'.repeat(2);
    return `<tr>${word}${cells}${gone}<td class="num err">${fmtN(r.ms)}</td></tr>`;
  }
  return (
    `<tr>${word}<td>${renderDefs(r)}</td>` +
    audioCell(p, r, 'brE') + audioCell(p, r, 'amE') +
    audioTime(p, r, 'brE') + audioTime(p, r, 'amE') +
    `<td class="num">${fmtN(r.ms)}</td></tr>`
  );
}

function renderDefs(r) {
  const defs = r.definitions.map((d) => stripHtml(d)).filter(Boolean);
  const extra = renderExtra(r.extra);
  if (!defs.length) return `<span class="dash">no definition returned</span>${extra}`;
  const first = esc(clip(defs[0], 220));
  if (defs.length === 1) return first + extra;
  const rest = defs.slice(1).map((d) => `<li>${esc(d)}</li>`).join('');
  return `${first}<details class="more"><summary>+${defs.length - 1} more (${defs.length} senses)</summary><ol class="defs" start="2">${rest}</ol></details>${extra}`;
}

function renderExtra(extra) {
  if (!extra) return '';
  const bits = [];
  if (extra.ipa) bits.push(`IPA /${esc(extra.ipa)}/`);
  if (extra.arpabet) bits.push(`ARPAbet ${esc(extra.arpabet)}`);
  if (extra.suggestions?.length) bits.push(`did you mean: ${extra.suggestions.map(esc).join(', ')}`);
  return bits.length ? `<div class="extra">${bits.join(' · ')}</div>` : '';
}

function audioCell(p, r, dialect) {
  const a = r.audio?.[dialect];
  if (!a) return noDialect(p, dialect) ? '<td class="c na">n/a</td>' : '<td class="c dash">—</td>';
  if (a.status !== 200) return `<td class="c err" title="${attr(a.url)}">${esc(String(a.status))}</td>`;
  return `<td class="c"><audio controls preload="none" src="${attr(a.url)}"></audio></td>`;
}

function audioTime(p, r, dialect) {
  const a = r.audio?.[dialect];
  if (!a) return noDialect(p, dialect) ? '<td class="num na">n/a</td>' : '<td class="num dash">—</td>';
  return `<td class="num${a.status === 200 ? '' : ' err'}">${fmtN(a.ms)}</td>`;
}

function renderRejected() {
  const bulk = live.filter((p) => !p.probeable);
  const items = [
    ...bulk.map((p) => `<li><b>${esc(p.name)}</b>: not probed. ${esc(p.note ?? 'Not a live API.')}</li>`),
    ...rejected.map((p) => `<li><b>${esc(p.name)}</b>: ${esc(p.reason)}</li>`),
  ];
  return items.length ? `<h2 id="rejected">Considered and rejected</h2><ul class="rejected">${items.join('')}</ul>` : '';
}

function noResults() {
  return '<div class="callout">No probe results yet. Run <code>npm run probe -- --warm</code>, then <code>npm run build</code>.</div>';
}

// ---------------------------------------------------------------- helpers

function summarise(rows) {
  if (rows.every((r) => r.status === 'skipped')) return `skipped: ${rows[0]?.skipped ?? 'no key'}`;
  const ok = rows.filter((r) => r.definitions);
  const withDefs = ok.filter((r) => r.definitions.length).length;
  const parts = [`${withDefs}/${rows.length} words defined`];
  if (ok.length) parts.push(`median def t ${fmtMs(median(ok.map((r) => r.ms)))}`);
  const failed = rows.length - ok.length;
  if (failed) parts.push(`${failed} failed`);
  const audio = (d) => rows.filter((r) => r.audio?.[d]?.status === 200).length;
  parts.push(`🇬🇧 audio ${audio('brE')}/${rows.length}`, `🇺🇸 audio ${audio('amE')}/${rows.length}`);
  return parts.join(' · ');
}

function regBadge(p) {
  if (manualIds.has(p.id) || p.registration === 'manual-approval') return '<span class="badge manual">manual approval</span>';
  if (p.registration === 'none') return '<span class="badge none">no registration</span>';
  return `<span class="badge">${esc(p.registration)}</span>`;
}

function noDialect(p, d) {
  return p.audio?.[d] === 'no' || p.audio?.[d] === 'n/a';
}
function median(xs) {
  const s = [...xs].sort((a, b) => a - b);
  const m = s.length >> 1;
  return s.length % 2 ? s[m] : (s[m - 1] + s[m]) / 2;
}
function fmtN(ms) {
  return Math.round(ms).toLocaleString('en-US');
}
function fmtMs(ms) {
  return `${fmtN(ms)} ms`;
}
function clip(s, n) {
  return s.length > n ? `${s.slice(0, n - 1)}…` : s;
}
function esc(s) {
  const map = { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' };
  return String(s ?? '').replace(/[&<>"']/g, (c) => map[c]);
}
function attr(url) {
  const s = String(url ?? '');
  return /^https?:\/\//i.test(s) ? esc(s) : '#';
}
