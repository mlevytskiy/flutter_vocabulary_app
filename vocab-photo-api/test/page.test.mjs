import assert from "node:assert/strict";
import { createHash, randomUUID } from "node:crypto";
import { test } from "node:test";
import { get, pagePost, publish, storedRows, uploadSource } from "./helpers.mjs";

// T11: the server-rendered page (ADR-0002) -- columns from the data, the photo
// markup from the declared slots, and the content security policy (sad §8).

const PNG = Buffer.from(
  "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII=",
  "base64"
);

async function page(id) {
  const res = await get(`/s/${id}`);
  assert.equal(res.status, 200);
  return { res, html: await res.text() };
}

/** The <th> of each column, in order, as `Word` or `+ Definition` for a collapsed one. */
function headers(html) {
  const thead = html.match(/<thead>(.*?)<\/thead>/s)[1];
  return [...thead.matchAll(/<th class="c-\w+" scope="col">(.*?)<\/th>/g)].map((m) =>
    m[1].replace(/<[^>]+>/g, "")
  );
}

test("cell text is escaped, never markup, and the page sends its CSP (AC-33, sad §8)", async () => {
  const { id } = await publish({ entries: [{ word: "<script>alert(1)</script>", translation: "<b>x</b>" }] });
  const { res, html } = await page(id);

  assert.match(html, /<div class="v">&lt;script&gt;alert\(1\)&lt;\/script&gt;<\/div>/);
  assert.match(html, /<div class="v">&lt;b&gt;x&lt;\/b&gt;<\/div>/);
  assert.doesNotMatch(html, /<script>alert/);
  assert.doesNotMatch(html, /<b>x/);

  const csp = res.headers.get("content-security-policy") ?? "";
  assert.match(csp, /default-src 'none'/);
  assert.match(csp, /script-src 'self'(;|$)/);
  assert.match(csp, /img-src 'self'(;|$)/);
  assert.match(csp, /connect-src 'self' https:\/\/translate\.googleapis\.com(;|$)/);
  assert.equal(res.headers.get("cache-control"), "no-store");
  assert.equal(res.headers.get("referrer-policy"), "same-origin");

  // The one inline <style> is allowed by its hash; nothing else inline is.
  const style = html.match(/<style>(.*?)<\/style>/s)[1];
  const hash = createHash("sha256").update(style).digest("base64");
  assert.match(csp, new RegExp(`style-src 'sha256-${hash.replace(/[+/]/g, "\\$&")}'(;|$)`));
  assert.doesNotMatch(csp, /unsafe-inline/);
});

test("the page loads the versioned script, served with a one-year immutable cache", async () => {
  const { id } = await publish();
  const { html } = await page(id);
  const src = html.match(/<script type="module" src="(\/assets\/page-[0-9a-f]{12}\.js)"><\/script>/)[1];

  const res = await get(src);
  assert.equal(res.status, 200);
  assert.match(res.headers.get("content-type") ?? "", /^text\/javascript/);
  assert.equal(res.headers.get("cache-control"), "public, max-age=31536000, immutable");
  assert.equal(res.headers.get("x-content-type-options"), "nosniff");
  assert.match(await res.text(), /classList\.add\("js"\)/);

  // Another version's URL is not answered with this version's code.
  assert.equal((await get("/assets/page-000000000000.js")).status, 404);
});

test("a translation-only session collapses Definition to its add control (AC-21)", async () => {
  const { id } = await publish({
    detail: "translation",
    entries: [
      { word: "apple", translation: "яблуко" },
      { word: "pear", translation: "груша" },
    ],
  });
  const { html } = await page(id);

  assert.deepEqual(headers(html), ["Word", "Translation", "+ Definition"]);
  assert.match(html, /<button type="button" class="add-col" data-open="definition"/);
  assert.match(html, /<main [^>]*class="no-definition"/);
});

test("a both-filled session shows all three columns, whatever the mode (AC-22, AC-27)", async () => {
  const { id } = await publish({
    detail: "translation",
    entries: [
      { word: "kettle", translation: "чайник", definition: "definition: a pot\nexample: boil the kettle" },
      { word: "cup", translation: "чашка" },
    ],
  });
  const { html } = await page(id);

  assert.deepEqual(headers(html), ["Word", "Translation", "Definition"]);
  assert.doesNotMatch(html, /class="add-col"/);
  assert.doesNotMatch(html, /<main [^>]*class="[^"]*no-/);
  // The line break is kept as text, shown by `white-space: pre-wrap` (AC-02).
  assert.match(html, /<div class="v">definition: a pot\nexample: boil the kettle<\/div>/);
  assert.match(html, /Definitions: Merriam-Webster/);
});

test("a definition-only session collapses Translation instead", async () => {
  const { id } = await publish({ detail: "definition", entries: [{ word: "cup", translation: "", definition: "a vessel" }] });
  const { html } = await page(id);

  assert.deepEqual(headers(html), ["Word", "+ Translation", "Definition"]);
});

test("rows carry their id, source photo and cell revisions for the script", async () => {
  const photo = randomUUID();
  const { id } = await publish({
    sources: [{ id: photo, order: 0 }],
    entries: [
      { word: "kettle", translation: "чайник", sourceId: photo },
      { word: "typed", translation: "набрано" },
    ],
  });
  const { html } = await page(id);

  assert.match(html, /<main data-session="[^"]+" data-rev="\d+"/);
  const rows = [...html.matchAll(/<tr data-row="([^"]+)"([^>]*)>/g)];
  assert.equal(rows.length, 2);
  assert.match(rows[0][2], new RegExp(`data-source="${photo}"`));
  assert.doesNotMatch(rows[1][2], /data-source/);
  assert.match(html, /<td class="c-word" data-field="word" data-rev="\d+">/);
});

test("a photo-less session has no photo area and no photo button (AC-08, AC-24, AC-26)", async () => {
  const { id } = await publish({ entries: [{ word: "apple", translation: "яблуко" }] });
  const { html } = await page(id);

  assert.doesNotMatch(html, /<img/i);
  assert.doesNotMatch(html, /<aside/);
  assert.doesNotMatch(html, /class="photo-button/);
  assert.doesNotMatch(html, /<main [^>]*has-photos/);
});

test("declared photos render in order, a pending one as a placeholder; one photo is a single thumbnail", async () => {
  const [first, second, third] = [randomUUID(), randomUUID(), randomUUID()];
  const many = await publish({
    sources: [
      { id: first, order: 0 },
      { id: second, order: 1 },
      { id: third, order: 2 },
    ],
    entries: [{ word: "kettle", translation: "чайник", sourceId: first }],
  });
  assert.equal((await uploadSource(many.id, first, PNG)).status, 200);
  assert.equal((await uploadSource(many.id, third, PNG)).status, 200);
  const { html } = await page(many.id);

  const slides = [...html.matchAll(/<figure class="slide" data-source="([^"]+)">(.*?)<\/figure>/g)];
  assert.deepEqual(
    slides.map((m) => m[1]),
    [first, second, third]
  );
  assert.match(slides[0][2], new RegExp(`<img src="/s/${many.id}/sources/${first}"`));
  assert.match(slides[1][2], /class="placeholder"/);
  assert.doesNotMatch(slides[1][2], /<img/);
  assert.match(slides[2][2], /<figcaption>3 of 3<\/figcaption>/);
  assert.match(html, /class="photo-button stack" aria-label="Show the 3 source photos"/);

  const photo = randomUUID();
  const one = await publish({ sources: [{ id: photo, order: 0 }], entries: [{ word: "cup", translation: "чашка" }] });
  const single = (await page(one.id)).html;
  assert.match(single, /class="photo-button" aria-label="Show the source photo"/);
  // The phone's photo button sits beside the download link.
  assert.match(single, /<p class="actions"><a class="btn"[^>]*>Download for AnkiDroid<\/a><button type="button" class="photo-button"/);
});

// The title row carries the phone's short meta line; the long one stays for the wide layout.
test("the title carries a short meta line with a numeric expiry date", async () => {
  const session = await publish({ entries: [{ word: "cup", translation: "чашка" }, { word: "tea", translation: "чай" }] });
  const { html } = await page(session.id);
  const expires = new Date(Date.now() + 30 * 24 * 3600 * 1000);
  const two = (n) => String(n).padStart(2, "0");
  const day = (d) => `${two(d.getUTCDate())}.${two(d.getUTCMonth() + 1)}.${d.getUTCFullYear()}`;
  const short = html.match(/<span class="meta-short">2 words · until (\d\d\.\d\d\.\d{4})<\/span>/);
  assert.ok(short, "short meta line");
  // Around the 30-day expiry (either side of a UTC midnight).
  assert.ok([day(expires), day(new Date(expires.getTime() - 60_000))].includes(short[1]), short[1]);
  assert.match(html, /<header class="title"><h1>Vocabulary<\/h1><span class="meta-short">/);
  assert.match(html, /<p class="meta">2 words · published .* · available until /);
});

// T16: the pager's arrows and the phone dialog's frame are in the markup,
// hidden until the script wires them (AC-05, AC-07); a photo-less page has neither.
test("a page with photos has the pager arrows, a focusable track and the photo dialog", async () => {
  const [first, second] = [randomUUID(), randomUUID()];
  const { id } = await publish({
    sources: [
      { id: first, order: 0 },
      { id: second, order: 1 },
    ],
    entries: [{ word: "kettle", translation: "чайник", sourceId: first }],
  });
  const { html } = await page(id);

  assert.match(html, /<div class="pager-track" tabindex="0" aria-label="Source photos, use the arrow keys to move">/);
  assert.match(html, /<div class="pager-nav" hidden>.*data-pager="prev" aria-label="Previous photo".*data-pager="next" aria-label="Next photo"/s);
  const dialog = html.match(/<dialog class="photo-dialog" aria-label="Source photos">(.*?)<\/dialog>/s);
  assert.ok(dialog, "the photo dialog is rendered");
  assert.match(dialog[1], /class="dialog-count" aria-live="polite"/);
  assert.match(dialog[1], /data-dialog="close" aria-label="Close the photos"/);
  assert.match(dialog[1], /<div class="dialog-strip"><\/div>/);

  const bare = await publish({ entries: [{ word: "apple", translation: "яблуко" }] });
  const none = (await page(bare.id)).html.split("<body>")[1];
  assert.doesNotMatch(none, /<dialog/);
  assert.doesNotMatch(none, /class="pager-nav"/);
});

// AC-06, AC-34: only a recognised row is linked to a photo, and it stays linked
// after its word is corrected; a typed row and a row added on the page are not.
test("an edited recognised row keeps its photo; typed and page-added rows have none", async () => {
  const photo = randomUUID();
  const { id } = await publish({
    sources: [{ id: photo, order: 0 }],
    entries: [
      { word: "kettel", translation: "чайник", sourceId: photo },
      { word: "typed", translation: "набрано" },
    ],
  });
  const [kettle] = storedRows(id);
  const fixed = await pagePost(`/s/${id}/cells`, { rowId: kettle.id, field: "word", value: "kettle", baseRev: kettle.word_rev });
  assert.equal(fixed.status, 200);
  const added = randomUUID();
  assert.equal((await pagePost(`/s/${id}/rows`, { rowId: added, field: "word", value: "cup" })).status, 200);
  const { html } = await page(id);

  const rows = Object.fromEntries(
    [...html.matchAll(/<tr data-row="([^"]+)"([^>]*)>.*?<td class="c-word"[^>]*><div class="v">([^<]*)<\/div>/g)].map((m) => [
      m[3],
      m[2],
    ])
  );
  assert.match(rows.kettle, new RegExp(`data-source="${photo}"`));
  assert.doesNotMatch(rows.typed, /data-source/);
  assert.doesNotMatch(rows.cup, /data-source/);
});

test("a row with an empty word carries the needs-a-word mark (AC-31)", async () => {
  const { id } = await publish({
    entries: [
      { word: "apple", translation: "яблуко" },
      { word: "pear", translation: "груша" },
    ],
  });
  const [, pear] = storedRows(id);
  const cleared = await pagePost(`/s/${id}/cells`, { rowId: pear.id, field: "word", value: "", baseRev: pear.word_rev });
  assert.equal(cleared.status, 200);
  const { html } = await page(id);

  const rows = [...html.matchAll(/<tr data-row="[^"]+"([^>]*)>/g)].map((m) => m[1]);
  assert.doesNotMatch(rows[0], /needs-word/);
  assert.match(rows[1], /class="needs-word"/);
  assert.match(html, /not in the download — needs a word/);
});
