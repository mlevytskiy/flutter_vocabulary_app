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
