import assert from "node:assert/strict";
import { test } from "node:test";
import { get, publish } from "./helpers.mjs";

// collections-screen T23: the stored title is the shared page's heading and document title
// (screens SCR-14, contract getSessionPage; AC-29, AC-30, AC-33).

const entries = [{ word: "get over", translation: "подолати" }];

async function html(body) {
  const { id } = await publish(body);
  const res = await get(`/s/${id}`);
  assert.equal(res.status, 200);
  return res.text();
}

const heading = (page) => page.match(/<header class="title(?: named)?"><h1>(.*?)<\/h1>/s)[1];
const docTitle = (page) => page.match(/<title>(.*?)<\/title>/s)[1];
/** The rules inside the phone media query of the inline stylesheet. */
const phoneCss = (page) => page.match(/@media \(max-width: 899\.98px\) \{([\s\S]*?)\n  \}/)[1];

test("SCR-14 named: the h1 and the document title show the collection's name (AC-29)", async () => {
  const page = await html({ title: "Speaking club 12", entries });
  assert.equal(heading(page), "Speaking club 12");
  assert.equal(docTitle(page), "Speaking club 12 — 1 word");
});

test("SCR-14 before this feature: NULL keeps Vocabulary exactly as today", async () => {
  const page = await html({ entries: [...entries, { word: "apple", translation: "яблуко" }] });
  assert.match(page, /<header class="title"><h1>Vocabulary<\/h1><span class="meta-short">2 words · until /);
  assert.equal(docTitle(page), "Vocabulary — 2 words");
  // The unnamed header keeps today's one-line phone rules untouched.
  const css = phoneCss(page);
  assert.match(css, /\.title \{ margin: 0 0 12px; flex-wrap: nowrap; column-gap: 6px; \}/);
  assert.match(css, /\.title h1 \{ flex: none; \}/);
});

test("SCR-14 markup in the name: shown as text, never markup (spec §6.1)", async () => {
  const page = await html({ title: "<b>x</b> & \"Unit\" '3'", entries });
  assert.equal(heading(page), "&lt;b&gt;x&lt;/b&gt; &amp; &quot;Unit&quot; &#39;3&#39;");
  assert.equal(docTitle(page), "&lt;b&gt;x&lt;/b&gt; &amp; &quot;Unit&quot; &#39;3&#39; — 1 word");
  assert.doesNotMatch(page, /<b>x/);
});

test("SCR-14 long name: a 60-character name is whole and wraps on a phone without sideways scroll", async () => {
  const name = "Supercalifragilisticexpialidocious".repeat(2).slice(0, 60);
  const page = await html({ title: name, entries });
  assert.equal(heading(page), name);
  assert.match(page, /<header class="title named"><h1>/);
  const css = phoneCss(page);
  assert.match(css, /\.title\.named \{[^}]*flex-wrap: wrap;/);
  assert.match(css, /\.title\.named h1 \{[^}]*flex: 0 1 auto;[^}]*overflow-wrap: anywhere;/);
});

test("the page holds only this collection: no folders, other collections, bin or session wording (AC-30, AC-33)", async () => {
  const page = await html({ title: "Speaking club 12", entries });
  const visible = page.replace(/<style>[\s\S]*?<\/style>/, "").replace(/<[^>]+>/g, " ");
  assert.doesNotMatch(visible, /\bfolders?\b|\bcollections\b|recycle|\bbin\b|\bsessions?\b/i);
  assert.doesNotMatch(page, /contenteditable[^>]*>[^<]*Speaking club 12|<input[^>]*Speaking club 12/);
});
