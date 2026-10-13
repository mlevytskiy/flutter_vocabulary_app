import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { test } from "node:test";
import vm from "node:vm";

// AC-20, AC-21: the page script keeps the dialogue pages in step with the change feed -- a dialogue
// appended by the app, a changed one (a partner's translation edit, a deleted word), an arrived
// picture, a removed dialogue -- each shown after one poll, without a reload, and never touching the
// word table (good-looking-web AC-36). The script runs here in node:vm against a small fake DOM
// (no package may be added), with a fake feed behind `fetch`. No Worker is needed.

const SCRIPT = readFileSync(new URL("../src/session/client/page.js", import.meta.url), "utf8");

// ---- a just-enough DOM ------------------------------------------------------------------------

const escapeHtml = (s) => s.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;").replace(/"/g, "&quot;").replace(/'/g, "&#39;");
const kebab = (s) => s.replace(/[A-Z]/g, (c) => "-" + c.toLowerCase());

class Node {
  constructor() {
    this.parentNode = null;
    this.childNodes = [];
  }
  get nextSibling() {
    const i = this.parentNode ? this.parentNode.childNodes.indexOf(this) : -1;
    return i >= 0 ? this.parentNode.childNodes[i + 1] ?? null : null;
  }
  remove() {
    if (this.parentNode) this.parentNode.childNodes.splice(this.parentNode.childNodes.indexOf(this), 1);
    this.parentNode = null;
  }
  replaceWith(node) {
    const parent = this.parentNode;
    const i = parent.childNodes.indexOf(this);
    node.remove();
    parent.childNodes[i] = node;
    node.parentNode = parent;
    this.parentNode = null;
  }
}

class Text extends Node {
  constructor(data) {
    super();
    this.data = data;
  }
  get textContent() {
    return this.data;
  }
}

class Element extends Node {
  constructor(tag) {
    super();
    this.tagName = tag.toUpperCase();
    this.attrs = new Map();
    const self = this;
    this.dataset = new Proxy(
      {},
      {
        get: (_, key) => self.attrs.get("data-" + kebab(String(key))),
        set: (_, key, value) => (self.attrs.set("data-" + kebab(String(key)), String(value)), true),
      }
    );
    this.classList = {
      add: (c) => {
        const list = new Set((self.attrs.get("class") ?? "").split(/\s+/).filter(Boolean));
        list.add(c);
        self.attrs.set("class", [...list].join(" "));
      },
      remove: (c) => {
        const list = (self.attrs.get("class") ?? "").split(/\s+/).filter((x) => x && x !== c);
        if (list.length > 0) self.attrs.set("class", list.join(" "));
        else self.attrs.delete("class");
      },
      contains: (c) => (self.attrs.get("class") ?? "").split(/\s+/).includes(c),
    };
  }
  get className() {
    return this.attrs.get("class") ?? "";
  }
  set className(v) {
    this.attrs.set("class", v);
  }
  get src() {
    return this.attrs.get("src");
  }
  set src(v) {
    this.attrs.set("src", v);
  }
  get alt() {
    return this.attrs.get("alt");
  }
  set alt(v) {
    this.attrs.set("alt", v);
  }
  get loading() {
    return this.attrs.get("loading");
  }
  set loading(v) {
    this.attrs.set("loading", v);
  }
  setAttribute(k, v) {
    this.attrs.set(k, String(v));
  }
  getAttribute(k) {
    return this.attrs.get(k) ?? null;
  }
  addEventListener() {}
  get children() {
    return this.childNodes.filter((n) => n instanceof Element);
  }
  get firstElementChild() {
    return this.children[0] ?? null;
  }
  get textContent() {
    return this.childNodes.map((n) => n.textContent).join("");
  }
  set textContent(v) {
    for (const c of this.childNodes) c.parentNode = null;
    this.childNodes = [];
    if (v !== "") this.append(new Text(String(v)));
  }
  append(...nodes) {
    for (const n of nodes) this.insertBefore(typeof n === "string" ? new Text(n) : n, null);
  }
  prepend(node) {
    this.insertBefore(node, this.childNodes[0] ?? null);
  }
  insertBefore(node, ref) {
    node.remove();
    const i = ref ? this.childNodes.indexOf(ref) : this.childNodes.length;
    this.childNodes.splice(i, 0, node);
    node.parentNode = this;
    return node;
  }
  matches(selector) {
    return selector.split(/(?=[.#\[])/).every((part) => {
      if (/^[a-z]/i.test(part)) return this.tagName === part.toUpperCase();
      if (part[0] === ".") return this.classList.contains(part.slice(1));
      if (part[0] === "#") return this.attrs.get("id") === part.slice(1);
      const m = /^\[([^=\]]+)(?:=["']?([^"'\]]*)["']?)?\]$/.exec(part);
      return m ? (m[2] === undefined ? this.attrs.has(m[1]) : this.attrs.get(m[1]) === m[2]) : false;
    });
  }
  closest(selector) {
    for (let el = this; el instanceof Element; el = el.parentNode) if (el.matches(selector)) return el;
    return null;
  }
  querySelectorAll(selector) {
    const chain = selector.trim().split(/\s+/);
    const out = [];
    const walk = (el, depth) => {
      for (const child of el.children) {
        if (child.matches(chain[depth])) {
          if (depth === chain.length - 1) out.push(child);
          else walk(child, depth + 1);
        }
        walk(child, depth);
      }
    };
    walk(this, 0);
    return [...new Set(out)];
  }
  querySelector(selector) {
    return this.querySelectorAll(selector)[0] ?? null;
  }
}

/** The markup of a node, as the Worker renders a dialogue (page.ts `renderDialogue`). */
function html(node) {
  if (node instanceof Text) return escapeHtml(node.data);
  const attrs = [...node.attrs].map(([k, v]) => ` ${k}="${escapeHtml(v)}"`).join("");
  return `<${node.tagName.toLowerCase()}${attrs}>${node.childNodes.map(html).join("")}</${node.tagName.toLowerCase()}>`;
}

// ---- the page under test ------------------------------------------------------------------------

/** A page as the Worker serves it: the table with a typed-in cell, no dialogues unless `initial` says so. */
function loadPage() {
  const document = {
    documentElement: new Element("html"),
    visibilityState: "visible",
    activeElement: null,
    createElement: (tag) => new Element(tag),
    createTextNode: (data) => new Text(data),
    addEventListener() {},
  };
  const main = new Element("main");
  main.attrs.set("data-session", "SID");
  main.attrs.set("data-rev", "5");
  main.attrs.set("data-max-rows", "500");
  const table = new Element("table");
  const tbody = new Element("tbody");
  const typed = new Element("span");
  typed.className = "v";
  typed.textContent = "half-typed transl";
  tbody.append(typed);
  table.append(tbody);
  const toasts = new Element("div");
  toasts.className = "toasts";
  main.append(table, toasts);
  document.querySelector = (selector) => (selector === "main[data-session]" ? main : null);

  const timers = [];
  const requests = [];
  const feeds = [];
  const window = {
    matchMedia: () => ({ matches: false, addEventListener() {} }),
    setTimeout: (fn) => timers.push(fn),
    clearTimeout() {},
    addEventListener() {},
    location: { reload() {}, assign() {} },
    open: () => null,
  };
  const context = vm.createContext({
    document,
    window,
    Element,
    HTMLElement: Element,
    HTMLDialogElement: class {},
    HTMLAnchorElement: class {},
    HTMLSpanElement: class {},
    HTMLTemplateElement: class {},
    HTMLTableCellElement: class {},
    fetch: async (url) => {
      requests.push(url);
      const feed = feeds.shift() ?? { rev: 5 };
      return { ok: true, status: 200, json: async () => feed };
    },
  });
  vm.runInContext(SCRIPT, context);
  return {
    main,
    tbody,
    typed,
    requests,
    /** One poll against this feed: the scheduled timer fires and the answer is applied. */
    async poll(feed) {
      feeds.push(feed);
      timers.pop()();
      await new Promise((resolve) => setImmediate(resolve));
    },
    sections: () => main.querySelectorAll(".dialogue-page"),
    ids: () => main.querySelectorAll(".dialogue-page").map((s) => s.dataset.dialogue),
  };
}

const dialogue = (id, position, lines, words, picture = null) => ({ id, position, lines, picture, words });
const word = (rowId, w, translation, places, definition = "") => ({ rowId, word: w, translation, definition, places });

const D1 = dialogue("d1", 0, ["A: Grab the rope!", "B: I can't lift it."], [
  word("r1", "grab", "хапати", [[[3, 7]], []]),
  word("r2", "rope", "мотузка", [[[12, 16]], []]),
]);
const D2 = dialogue("d2", 1, ["Look at the tide."], [word("r3", "tide", "приплив", [[[12, 16]]])]);
const D3 = dialogue("d3", 2, ["The fog is thick."], [word("r4", "fog", "туман", [[[4, 7]]])]);

test("a dialogue appended by the app shows at the end after one poll, with bold places and its words", async () => {
  const page = loadPage();
  assert.equal(page.sections().length, 0);
  await page.poll({ rev: 6, dialogues: [D1, D2] });
  assert.deepEqual(page.ids(), ["d1", "d2"]);
  assert.ok(page.main.classList.contains("has-dialogues"));
  const container = page.main.querySelector(".dialogues");
  assert.equal(container.getAttribute("aria-label"), "Dialogues from the film");
  assert.equal(container.nextSibling, page.main.querySelector(".toasts"));

  await page.poll({ rev: 7, dialogues: [D3] });
  assert.deepEqual(page.ids(), ["d1", "d2", "d3"]);
  assert.equal(
    html(page.sections()[0]),
    '<section class="dialogue-page" data-dialogue="d1" data-position="0">' +
      '<div class="dialogue-lines"><p class="dialogue-line">A: <strong>Grab</strong> the <strong>rope</strong>!</p>' +
      "<p class=\"dialogue-line\">B: I can&#39;t lift it.</p></div>" +
      '<ul class="dialogue-words">' +
      '<li data-row="r1"><span class="dw-word">grab</span> <span class="dw-translation">хапати</span></li>' +
      '<li data-row="r2"><span class="dw-word">rope</span> <span class="dw-translation">мотузка</span></li>' +
      "</ul></section>"
  );
});

test("the page asks the feed from the revision it has taken in", async () => {
  const page = loadPage();
  await page.poll({ rev: 6, dialogues: [D1] });
  await page.poll({ rev: 9 });
  assert.match(page.requests[0], /\/s\/SID\/changes\?since=5$/);
  assert.match(page.requests[1], /\/s\/SID\/changes\?since=6$/);
});

test("a partner's translation edit and a deleted word re-render the dialogue's word list and bold places", async () => {
  const page = loadPage();
  await page.poll({ rev: 6, dialogues: [D1, D2] });
  const untouched = page.sections()[1];
  const edited = dialogue("d1", 0, D1.lines, [word("r1", "grab", "схопити", [[[3, 7]], []], "to seize"), D1.words[1]]);
  await page.poll({ rev: 7, dialogues: [edited] });
  const first = page.sections()[0];
  assert.match(html(first), /<span class="dw-translation">схопити<\/span> <span class="dw-definition">to seize<\/span>/);
  assert.equal(page.sections()[1], untouched, "another dialogue is not re-rendered");

  // The partner deletes the row of "rope": the feed sends the dialogue without that word.
  const withoutRope = dialogue("d1", 0, D1.lines, [edited.words[0]]);
  await page.poll({ rev: 8, dialogues: [withoutRope] });
  const text = html(page.sections()[0]);
  assert.ok(!text.includes("rope</span>"), "the deleted word is gone from the list");
  assert.ok(text.includes("the rope!</p>"), "and no longer bold");
  assert.ok(text.includes("<strong>Grab</strong>"));
  assert.deepEqual(page.ids(), ["d1", "d2"]);
});

test("an arrived scene picture shows on its dialogue, cache-busted by its revision", async () => {
  const page = loadPage();
  await page.poll({ rev: 6, dialogues: [D1] });
  assert.equal(page.main.querySelector(".dialogue-picture"), null);
  await page.poll({ rev: 7, dialogues: [{ ...D1, picture: { mediaType: "image/png", rev: 7 } }] });
  const img = page.main.querySelector(".dialogue-picture");
  assert.equal(img.getAttribute("src"), "/s/SID/dialogues/d1/picture?v=7");
  assert.equal(img.getAttribute("alt"), "Scene picture for this dialogue");
  assert.equal(img.getAttribute("loading"), "lazy");
  assert.deepEqual(page.ids(), ["d1"]);
});

test("a removed dialogue drops, and the last one takes the container with it", async () => {
  const page = loadPage();
  await page.poll({ rev: 6, dialogues: [D1, D2] });
  await page.poll({ rev: 7, removedDialogues: ["d1"] });
  assert.deepEqual(page.ids(), ["d2"]);
  await page.poll({ rev: 8, removedDialogues: ["d2", "unknown"] });
  assert.equal(page.main.querySelector(".dialogues"), null);
  assert.ok(!page.main.classList.contains("has-dialogues"));
});

test("a dialogue arriving between two others takes its place by position", async () => {
  const page = loadPage();
  await page.poll({ rev: 6, dialogues: [D1, D3] });
  await page.poll({ rev: 7, dialogues: [D2] });
  assert.deepEqual(page.ids(), ["d1", "d2", "d3"]);
});

test("text typed in the table survives every dialogue update (good-looking-web AC-36)", async () => {
  const page = loadPage();
  const before = html(page.tbody);
  await page.poll({ rev: 6, dialogues: [D1, D2] });
  await page.poll({ rev: 7, dialogues: [{ ...D1, picture: { mediaType: "image/png", rev: 7 } }] });
  await page.poll({ rev: 8, removedDialogues: ["d2"] });
  assert.equal(html(page.tbody), before);
  assert.equal(page.tbody.children[0], page.typed);
  assert.equal(page.typed.textContent, "half-typed transl");
});

test("dialogue text is set as text, never as markup, and overlapping places make one bold run", async () => {
  const page = loadPage();
  const text = '<img src=x onerror=alert(1)> give up & "go"';
  const at = text.indexOf("give up");
  const risky = dialogue("d9", 0, [text], [
    word("r1", "give up", "здатися", [[[at, at + 7]]]),
    word("r2", "up", "вгору", [[[at + 5, at + 7]]]),
  ]);
  await page.poll({ rev: 6, dialogues: [risky] });
  const line = page.main.querySelector(".dialogue-line");
  assert.equal(line.querySelector("img"), null);
  assert.equal(line.textContent, '<img src=x onerror=alert(1)> give up & "go"');
  assert.equal(line.querySelectorAll("strong").length, 1);
  assert.equal(line.querySelector("strong").textContent, "give up");
});

test("nothing on a dialogue page is a control (AC-22)", async () => {
  const page = loadPage();
  await page.poll({ rev: 6, dialogues: [dialogue("d1", 0, D1.lines, D1.words, { mediaType: "image/png", rev: 6 })] });
  const section = page.sections()[0];
  for (const tag of ["button", "input", "textarea", "a", "select"]) assert.equal(section.querySelector(tag), null, tag);
});
