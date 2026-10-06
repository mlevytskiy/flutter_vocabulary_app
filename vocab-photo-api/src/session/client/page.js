// @ts-check
/**
 * The shared page's browser script (ADR-0002). The Worker imports this file as
 * text (wrangler.jsonc `rules`) and serves it at /assets/page-<hash>.js; the
 * table is fully rendered without it. Plain JavaScript with JSDoc types, checked
 * by `npm run typecheck` (tsconfig.client.json). Text reaches the page only
 * through `textContent`, never `innerHTML` (AC-33).
 *
 * One state object holds every cell's saved value and revision (ADR-0004). A
 * cell saves when the partner leaves it, with the revision it was loaded or
 * last saved at; the Worker answers saved, refused (the text stays, marked not
 * saved, with the reason in plain words) or conflict (both values are shown and
 * the partner picks one). Nothing is re-rendered: the two layouts are CSS on
 * this one DOM, so a resize keeps focus and typed text (AC-36).
 *
 * Other partners' saves arrive by polling the change feed from the last
 * revision this page has taken in (ADR-0005), only while the page is visible
 * and in use. A change for a cell the partner is in, or for a row whose Undo is
 * running, is held rather than applied; it surfaces as the AC-11 choice when
 * they save, or as "changed meanwhile" when the delete is sent (AC-15b).
 *
 * Lightnings fill a translation from the translation endpoint in this browser
 * (ADR-0007) and a definition through the Worker's metered route (T9); a
 * column's lightning fills its empty cells one by one, paced (sad §4, §8).
 */

/** @typedef {"word" | "translation" | "definition"} Field */

/**
 * @typedef {object} Cell
 * @property {Row} row
 * @property {Field} field
 * @property {HTMLTableCellElement} td
 * @property {HTMLElement} el the editable text, `.v`
 * @property {HTMLElement | null} note the status line under the text, made when first needed
 * @property {HTMLButtonElement | null} bolt the lightning (Translation and Definition only)
 * @property {string} saved the value as last saved (or as the page was loaded)
 * @property {number} rev the revision of `saved`
 * @property {"idle" | "saving" | "unsaved" | "conflict"} status
 * @property {boolean} again another save is wanted once the one in flight ends
 * @property {{ value: string, rev: number } | null} theirs the other value, during a conflict
 * @property {{ value: string, rev: number } | null} held another partner's save, not applied
 *   while this cell is being typed in or its row's Undo runs (ADR-0005)
 * @property {boolean} busy its lightning is running
 * @property {number} timer hides the "saved" confirmation
 */

/**
 * @typedef {object} Row
 * @property {string} id
 * @property {HTMLTableRowElement} tr
 * @property {Record<Field, Cell>} cells
 * @property {"new" | "adding" | "live"} phase "new": added by the plus button, not stored
 *   until a cell gets text; "adding": that first save is in flight; "live": the Worker has it
 * @property {boolean} pendingDelete hidden, with its Undo running (AC-15)
 */

/**
 * The Worker's answer to a page write: `{ error, code, … }` on refusal (sad §8);
 * a refused delete carries the row as it is now (`word`… and `revs`).
 * @typedef {{ error?: string, code?: string, rev?: number, value?: string, deleted?: boolean,
 *   word?: string, translation?: string, definition?: string, revs?: Record<Field, number>,
 *   resumesAt?: string }} Answer
 */

/**
 * A row as the change feed sends it: added, or with all three cells changed.
 * @typedef {{ rowId: string, sourceId: string | null, word: string, translation: string,
 *   definition: string, revs: Record<Field, number> }} FeedRow
 */

/**
 * The change feed's answer (T8): everything above `since`, or `reload` when the
 * list was republished meanwhile (ADR-0008).
 * @typedef {{ rev: number, reload?: boolean,
 *   cells?: { rowId: string, field: Field, value: string, rev: number }[],
 *   rows?: FeedRow[], deleted?: { rowId: string, rev: number }[],
 *   sources?: { id: string }[] }} Feed
 */

/** @typedef {"filled" | "nothing" | "paused" | "failed"} Fill */

/** @type {readonly Field[]} */
const FIELDS = ["word", "translation", "definition"];
/** @type {Record<Field, string>} */
const LABELS = { word: "Word", translation: "Translation", definition: "Definition" };
const SAVED_FOR_MS = 2000;
const UNDO_MS = 5000;
const NOTICE_MS = 6000;
/** A field in the Undo toast shows at most this many words (then "…"). */
const TOAST_WORDS = 8;
const REPORT_MS = 10000;
/** About every 5 s while the page is in use; an idle one stops after 5 min (ADR-0005). */
const POLL_MS = 5000;
const IDLE_MS = 5 * 60 * 1000;
/**
 * A column autofill saves each cell as its own request, at most 3 a second, so
 * it stays inside the page write limit with room for the other partner (sad §8).
 */
const COLUMN_GAP_MS = 340;
/** The translation endpoint (ADR-0007, T1), English to Ukrainian as in the app. */
const TRANSLATE_URL = "https://translate.googleapis.com/translate_a/single?client=gtx&sl=en&tl=uk&dt=t&q=";
/** How long the pager's scroll must be still before a swipe counts as done. */
const SETTLE_MS = 120;
/** The photo dialog (AC-07): the most a photo zooms, and what a double tap zooms to. */
const MAX_ZOOM = 4;
const TAP_ZOOM = 2.5;
const DOUBLE_TAP_MS = 300;
/** A swipe turns the photo when it covers this share of the width, or moves faster (px/ms). */
const SWIPE_SHARE = 0.2;
const SWIPE_SPEED = 0.4;
/** Below this a touch is a tap, not a drag (px). */
const TAP_SLOP = 10;
const SVG_NS = "http://www.w3.org/2000/svg";
/** The app's lightning (`Icons.electric_bolt`), drawn inline: images come only from this origin. */
const BOLT_PATH = "M11 21h-1l1-7H7.5c-.58 0-.57-.32-.38-.66.19-.34.05-.08.07-.12C8.48 10.94 10.42 7.54 13 3h1l-1 7h3.5c.49 0 .56.33.47.51l-.07.15C12.96 17.55 11 21 11 21z";

document.documentElement.classList.add("js");

const main = /** @type {HTMLElement | null} */ (document.querySelector("main[data-session]"));
const tbody = main?.querySelector("tbody") ?? null;
const blankRow = /** @type {HTMLTemplateElement | null} */ (main?.querySelector("template#blank-row") ?? null);
/** The wide layout, where the pager and its row highlighting are (spec §3: none on a phone). */
const WIDE = window.matchMedia("(min-width: 900px)");
const REDUCED_MOTION = window.matchMedia("(prefers-reduced-motion: reduce)");

const state = {
  session: main?.dataset.session ?? "",
  /**
   * The change feed's cursor: the session revision this page has taken in
   * everything up to (ADR-0005). Only the feed moves it -- a revision this
   * page's own save got may be above another partner's save it has not seen.
   */
  rev: Number(main?.dataset.rev ?? 0),
  /** @type {Map<string, Row>} */
  rows: new Map(),
  /** Set once the Worker says the list is gone: nothing more can be saved. */
  gone: false,
  /** The most rows a session may hold (AC-14), rendered by the Worker. */
  maxRows: Number(main?.dataset.maxRows ?? 500),
  /** Set once the list was republished under this page: polling has stopped (ADR-0008). */
  stale: false,
  poll: {
    /** The next poll, while one is scheduled. */
    timer: 0,
    inFlight: false,
    /** Another poll is wanted once the one in flight answers. */
    again: false,
    /** When the partner last did something on the page (ADR-0005). */
    lastActive: Date.now(),
    /** Stopped after IDLE_MS without activity; the "updates paused" hint shows. */
    idle: false,
    /** @type {HTMLElement | null} */
    hint: null,
  },
  /** @type {Set<Field>} the columns whose lightning is running */
  columnRuns: new Set(),
  /** The photo on display in the pager (AC-05); its rows are highlighted. */
  photo: {
    index: 0,
    /** @type {string | null} */
    source: /** @type {HTMLElement | null} */ (main?.querySelector(".photos .slide") ?? null)?.dataset.source ?? null,
    /** Waits for a swipe's scrolling to stop. */
    settle: 0,
  },
  /** The phone's photo dialog (AC-07): the photo shown, and where the table was when it opened. */
  dialog: { index: 0, scrollX: 0, scrollY: 0, tableLeft: 0, tableTop: 0 },
};

/**
 * A touch gesture in the photo dialog: the pointers down, the shown photo's
 * zoom (`scale`, moved by `x`/`y`), and where the gesture's current phase began.
 */
const gesture = {
  /** @type {Map<number, { x: number, y: number }>} */
  pointers: new Map(),
  scale: 1,
  x: 0,
  y: 0,
  startScale: 1,
  startX: 0,
  startY: 0,
  startDist: 0,
  startMid: { x: 0, y: 0 },
  downX: 0,
  downAt: 0,
  /** The finger went further than a tap. */
  moved: false,
  /** Two fingers were down: the gesture is a zoom, not a swipe or a tap. */
  pinched: false,
  lastTap: 0,
};

/** `plaintext-only` keeps pasted formatting out; older browsers throw on it. */
const PLAINTEXT_ONLY = (() => {
  const probe = document.createElement("div");
  try {
    probe.contentEditable = "plaintext-only";
    return probe.contentEditable === "plaintext-only";
  } catch {
    return false;
  }
})();

/**
 * POSTs a page write. Network failure answers status 0.
 * @param {string} path below /s/<id>
 * @param {Record<string, unknown>} body
 * @returns {Promise<{ status: number, body: Answer }>}
 */
async function api(path, body) {
  // The partner's own save or autofill counts as using the page (ADR-0005).
  active();
  try {
    const res = await fetch(`/s/${encodeURIComponent(state.session)}${path}`, {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify(body),
      // A save sent as the tab is hidden or closed still arrives.
      keepalive: true,
    });
    /** @type {Answer} */
    let answer = {};
    try {
      answer = await res.json();
    } catch {
      // Not JSON (a proxy error page): the status says enough.
    }
    return { status: res.status, body: answer };
  } catch {
    return { status: 0, body: {} };
  }
}

/**
 * The text of an editable cell. `innerText` turns any <br> or block a browser
 * inserted while typing into the line break the partner sees.
 * @param {Cell} cell
 */
function read(cell) {
  return cell.el.innerText;
}

/**
 * Leaves the stored text as a single text node once the partner is done with
 * the cell, so what is in the DOM is exactly what was saved.
 * @param {Cell} cell
 */
function normalise(cell) {
  if (cell.el.childElementCount > 0) cell.el.textContent = read(cell);
}

/**
 * Puts text into a cell as one text node. `filled` hides its lightning.
 * @param {Cell} cell
 * @param {string} text
 */
function setText(cell, text) {
  cell.el.textContent = text;
  markFilled(cell);
}

/** @param {Cell} cell */
function markFilled(cell) {
  cell.td.classList.toggle("filled", read(cell).trim() !== "");
}

/** @param {Cell} cell */
function noteOf(cell) {
  if (!cell.note) {
    cell.note = document.createElement("div");
    cell.note.className = "cell-note";
    cell.note.setAttribute("aria-live", "polite");
    cell.td.append(cell.note);
  }
  return cell.note;
}

/**
 * Shows a cell's state: "saving", "saved" (brief), "unsaved" with the reason,
 * "conflict" with both values and the choice, a "notice" from its lightning
 * (nothing found, autofill paused; the cell stays as it is), or nothing.
 * @param {Cell} cell
 * @param {"idle" | "saving" | "saved" | "unsaved" | "conflict" | "notice"} shown
 * @param {string} [message]
 */
function show(cell, shown, message = "") {
  window.clearTimeout(cell.timer);
  cell.status = shown === "saved" || shown === "notice" ? "idle" : shown;
  if (shown === "idle") {
    delete cell.td.dataset.state;
  } else {
    cell.td.dataset.state = shown;
  }
  if (shown === "idle" || shown === "saving") {
    cell.note?.replaceChildren();
    return;
  }
  const note = noteOf(cell);
  if (shown === "saved") {
    note.textContent = "Saved";
    cell.timer = window.setTimeout(() => show(cell, "idle"), SAVED_FOR_MS);
  } else if (shown === "unsaved") {
    note.textContent = `Not saved. ${message}`;
  } else if (shown === "notice") {
    note.textContent = message;
  } else if (cell.theirs) {
    note.replaceChildren(conflictChoice(cell, cell.theirs));
  }
}

/**
 * AC-11: someone saved this cell meanwhile. The partner's own text stays in the
 * cell; the saved one is shown beside it, and neither is dropped until they pick.
 * @param {Cell} cell
 * @param {{ value: string, rev: number }} theirs
 */
function conflictChoice(cell, theirs) {
  const box = document.createDocumentFragment();
  const said = document.createElement("p");
  said.textContent = "Someone else saved this meanwhile:";
  const value = document.createElement("q");
  value.textContent = theirs.value === "" ? "(empty)" : theirs.value;
  const mine = document.createElement("button");
  mine.type = "button";
  mine.textContent = "Keep mine";
  mine.addEventListener("click", () => {
    // Save on top of the other value: the cell is now at its revision.
    accept(cell, theirs);
    void save(cell);
  });
  const other = document.createElement("button");
  other.type = "button";
  other.textContent = "Use theirs";
  other.addEventListener("click", () => {
    accept(cell, theirs);
    setText(cell, theirs.value);
    wordChanged(cell);
    show(cell, "idle");
    releaseHeld(cell);
  });
  box.append(said, value, mine, other);
  return box;
}

/**
 * Takes a value the Worker holds as this cell's saved state.
 * @param {Cell} cell
 * @param {{ value: string, rev: number }} held
 */
function accept(cell, held) {
  cell.saved = held.value;
  cell.rev = held.rev;
  cell.theirs = null;
  cell.status = "idle";
  // A held change this answer already covers is no longer news.
  if (cell.held && cell.held.rev <= held.rev) cell.held = null;
}

/**
 * The cell is being typed in: another partner's save is held, not applied
 * (AC-12). Also while a save or its lightning is running, or it holds text the
 * Worker does not have yet.
 * @param {Cell} cell
 */
function inUse(cell) {
  return cell.busy || document.activeElement === cell.el || isDirty(cell);
}

/**
 * Another partner saved this cell (from the change feed, or the answer to a
 * lightning). An idle cell takes it; one in use holds it for the AC-11 choice;
 * during a conflict it becomes the value to choose against. Returns whether
 * the cell now shows it.
 * @param {Cell} cell
 * @param {{ value: string, rev: number }} change
 */
function applyRemote(cell, change) {
  if (change.rev <= cell.rev) return false;
  if (cell.status === "conflict") {
    if (cell.theirs && change.rev > cell.theirs.rev) {
      cell.theirs = change;
      show(cell, "conflict");
    }
    return false;
  }
  if (cell.row.pendingDelete || inUse(cell)) {
    if (!cell.held || change.rev > cell.held.rev) cell.held = change;
    return false;
  }
  accept(cell, change);
  setText(cell, change.value);
  wordChanged(cell);
  if (change.value !== "") openColumn(cell.field);
  return true;
}

/**
 * Once the partner is done with a cell, a change held for it meanwhile is
 * applied -- unless their own save has overtaken it (`accept` dropped it) or
 * the cell still holds unsaved text, where the next save meets it as a conflict.
 * @param {Cell} cell
 */
function releaseHeld(cell) {
  const held = cell.held;
  if (!held || cell.busy || cell.status !== "idle" || read(cell) !== cell.saved) return;
  cell.held = null;
  if (applyRemote(cell, held)) flash(cell.row);
}

/**
 * AC-31: a saved row with a blank word is not in the download.
 * @param {Cell} cell
 */
function wordChanged(cell) {
  if (cell.field === "word") cell.row.tr.classList.toggle("needs-word", cell.saved.trim() === "");
}

/**
 * Saves a cell whose text differs from its saved value. A save already in
 * flight is followed by one more once it answers; a conflict waits for the
 * partner's choice.
 * @param {Cell} cell
 */
async function save(cell) {
  if (state.gone || cell.status === "conflict") return;
  if (cell.status === "saving" || cell.row.phase === "adding") {
    cell.again = true;
    return;
  }
  const value = read(cell);
  if (value === cell.saved) {
    if (cell.status === "unsaved") show(cell, "idle");
    // Left without a change: what another partner saved meanwhile shows now.
    releaseHeld(cell);
    return;
  }
  if (cell.row.phase === "new") {
    await saveNewRow(cell, value);
    return;
  }
  show(cell, "saving");
  const { status, body } = await api("/cells", { rowId: cell.row.id, field: cell.field, value, baseRev: cell.rev });
  if (status === 200 && typeof body.rev === "number") {
    accept(cell, { value, rev: body.rev });
    wordChanged(cell);
    show(cell, "saved");
  } else if (status === 409 && typeof body.value === "string" && typeof body.rev === "number") {
    if (body.value === value) {
      // The other save wrote the same text: nothing to choose.
      accept(cell, { value, rev: body.rev });
      show(cell, "saved");
    } else {
      cell.theirs = { value: body.value, rev: body.rev };
      show(cell, "conflict");
    }
  } else {
    refused(cell, status, body);
  }
  if (cell.again) {
    cell.again = false;
    void save(cell);
  } else {
    releaseHeld(cell);
  }
}

/**
 * A save that did not land: the text stays, marked not saved, with the reason
 * -- field_too_long / list_full / rows_full (AC-10, AC-14, AC-38), a deleted
 * row, the write limit, no connection.
 * @param {Cell} cell
 * @param {number} status
 * @param {Answer} body
 */
function refused(cell, status, body) {
  if (status === 404 && body.code === "gone") {
    listGone();
    show(cell, "unsaved", body.error ?? "");
  } else if (status === 0) {
    show(cell, "unsaved", "There is no connection. It is tried again when you leave the cell.");
  } else {
    show(cell, "unsaved", body.error ?? "Something went wrong. Try again in a moment.");
  }
}

/**
 * AC-13: a row the plus button added is stored with its first text, at the end
 * of the table, every cell at the new revision. Its other cells wait for that
 * and then save on top of it.
 * @param {Cell} cell
 * @param {string} value
 */
async function saveNewRow(cell, value) {
  const row = cell.row;
  row.phase = "adding";
  show(cell, "saving");
  const { status, body } = await api("/rows", { rowId: row.id, field: cell.field, value });
  if (status === 200 && typeof body.rev === "number") {
    row.phase = "live";
    for (const field of FIELDS) row.cells[field].rev = body.rev;
    accept(cell, { value, rev: body.rev });
    wordChanged(row.cells.word);
    show(cell, "saved");
  } else {
    row.phase = "new";
    refused(cell, status, body);
  }
  for (const field of FIELDS) {
    const other = row.cells[field];
    if (other.again) {
      other.again = false;
      void save(other);
    }
  }
}

/** AC-32 while the page is open: the list expired. Text stays readable; nothing is editable. */
function listGone() {
  if (state.gone || !main) return;
  state.gone = true;
  const banner = document.createElement("p");
  banner.className = "banner";
  banner.setAttribute("role", "alert");
  banner.textContent = "This word list is gone: shared lists stay up for 30 days. Changes can no longer be saved.";
  main.prepend(banner);
  // No lightning is left to press.
  main.classList.add("read-only");
  state.poll.hint?.remove();
  for (const row of state.rows.values()) {
    for (const field of FIELDS) row.cells[field].el.contentEditable = "false";
  }
}

/**
 * A short message at the bottom of the page, read out by screen readers
 * (`.toasts` is aria-live). Returns the toast so an action can be added.
 * @param {string} text
 * @param {number} ms how long it stays
 * @param {{ text: string, className: string }[]} [parts] shown after the message on the same line
 * @param {HTMLButtonElement} [action] a button beside the message
 */
function toast(text, ms, parts = [], action) {
  const box = main?.querySelector(".toasts");
  const el = document.createElement("div");
  el.className = "toast";
  const body = document.createElement("div");
  body.className = parts.length ? "toast-body one-line" : "toast-body";
  body.append(text);
  parts.forEach((part, i) => {
    // The separator is text too, so a screen reader and a copy keep it.
    body.append(i === 0 ? " " : " · ");
    const span = document.createElement("span");
    span.className = part.className;
    span.textContent = part.text;
    body.append(span);
  });
  el.append(body);
  if (action) el.append(action);
  // Filled before it is added, so a screen reader reads it whole.
  box?.append(el);
  const timer = window.setTimeout(() => el.remove(), ms);
  return { el, close: () => { window.clearTimeout(timer); el.remove(); } };
}

/**
 * The first few words of a cell for a toast, on one line.
 * @param {string} text
 */
function clip(text) {
  const words = text.trim().split(/\s+/).filter(Boolean);
  return words.length > TOAST_WORDS ? `${words.slice(0, TOAST_WORDS).join(" ")}…` : words.join(" ");
}

/** A random row id the Worker accepts (`[A-Za-z0-9-]{1,64}`). */
function newId() {
  if (typeof crypto.randomUUID === "function") return crypto.randomUUID();
  const bytes = crypto.getRandomValues(new Uint8Array(16));
  return Array.from(bytes, (b) => b.toString(16).padStart(2, "0")).join("");
}

/**
 * AC-13: the plus button adds an empty row at the end and puts the cursor in
 * its word. Nothing is stored until a cell of it gets text; a second tap while
 * an empty added row is there goes back to that one.
 * @param {HTMLTableSectionElement} tbody
 * @param {HTMLTemplateElement} template
 */
function addBlankRow(tbody, template) {
  if (state.gone) return;
  for (const row of state.rows.values()) {
    if (row.phase === "new" && FIELDS.every((field) => read(row.cells[field]) === "")) {
      focusAtEnd(row.cells.word.el);
      return;
    }
  }
  let stored = 0;
  for (const row of state.rows.values()) if (row.phase !== "new") stored++;
  if (stored >= state.maxRows) {
    toast(`The list is full: it holds at most ${state.maxRows} rows.`, NOTICE_MS);
    return;
  }
  const tr = /** @type {HTMLTableRowElement} */ (
    /** @type {DocumentFragment} */ (template.content.cloneNode(true)).firstElementChild
  );
  tr.dataset.row = newId();
  tbody.append(tr);
  const row = adoptRow(tr, "new");
  focusAtEnd(row.cells.word.el);
}

/** @param {Row} row */
function dropRow(row) {
  row.tr.remove();
  state.rows.delete(row.id);
}

/**
 * A brief highlight: this row changed under the partner's eyes.
 * @param {Row} row
 */
function flash(row) {
  row.tr.classList.remove("changed");
  void row.tr.offsetWidth; // restart the highlight
  row.tr.classList.add("changed");
}

/**
 * AC-15: the row disappears at once and an Undo stays for five seconds. Only
 * then is the delete sent, with the revision of every cell as this page knows
 * them; leaving the page before that deletes nothing.
 * @param {Row} row
 */
function deleteRow(row) {
  if (state.gone || row.pendingDelete) return;
  row.pendingDelete = true;
  row.tr.classList.add("pending-delete");
  const undo = document.createElement("button");
  undo.type = "button";
  undo.textContent = "Undo";
  // Which row it was: its word, translation and definition as the page shows them.
  const parts = [];
  for (const field of FIELDS) {
    const text = clip(read(row.cells[field]));
    if (text) parts.push({ text, className: `toast-${field}` });
  }
  const shown = toast("Row deleted:", UNDO_MS, parts, undo);
  const timer = window.setTimeout(() => void commitDelete(row), UNDO_MS);
  undo.addEventListener("click", () => {
    window.clearTimeout(timer);
    shown.close();
    row.pendingDelete = false;
    row.tr.classList.remove("pending-delete");
    /** @type {HTMLElement | null} */ (row.tr.querySelector(".del"))?.focus();
    // What other partners saved while the row was hidden shows now.
    for (const field of FIELDS) releaseHeld(row.cells[field]);
  });
}

/** @param {Row} row */
function rowBusy(row) {
  return row.phase === "adding" || FIELDS.some((field) => row.cells[field].status === "saving");
}

/**
 * Sends a delete whose Undo ran out. A save of this row still in flight is
 * waited for, so its revision goes along. The Worker refuses when someone else
 * changed the row meanwhile: it comes back with their text (ADR-0004).
 * @param {Row} row
 */
async function commitDelete(row) {
  while (rowBusy(row)) await sleep(50);
  if (!row.pendingDelete || !state.rows.has(row.id)) return;
  if (row.phase === "new") {
    dropRow(row);
    return;
  }
  /** @type {Record<Field, number>} */
  const revs = { word: row.cells.word.rev, translation: row.cells.translation.rev, definition: row.cells.definition.rev };
  const { status, body } = await api("/rows/delete", { rowId: row.id, revs });
  if (status === 200 || (status === 404 && body.code === "unknown_row")) {
    dropRow(row);
    return;
  }
  row.pendingDelete = false;
  row.tr.classList.remove("pending-delete");
  if (status === 409 && body.revs) {
    for (const field of FIELDS) {
      const cell = row.cells[field];
      const value = body[field];
      const rev = body.revs[field];
      if (typeof value !== "string" || typeof rev !== "number") continue;
      if (cell.held && cell.held.rev <= rev) cell.held = null;
      if (cell.status === "idle" && read(cell) === cell.saved) {
        accept(cell, { value, rev });
        setText(cell, value);
        if (value !== "") openColumn(field);
      } else if (value !== cell.saved) {
        cell.theirs = { value, rev };
        show(cell, "conflict");
      }
    }
    wordChanged(row.cells.word);
    flash(row);
    toast("Someone changed this row meanwhile, so it was not deleted.", NOTICE_MS);
  } else if (status === 404 && body.code === "gone") {
    listGone();
  } else if (status === 0) {
    toast("There is no connection, so the row was not deleted.", NOTICE_MS);
  } else {
    toast(body.error ?? "Something went wrong, so the row was not deleted.", NOTICE_MS);
  }
  for (const field of FIELDS) releaseHeld(row.cells[field]);
}

/** @param {number} ms */
function sleep(ms) {
  return new Promise((resolve) => window.setTimeout(resolve, ms));
}

/** @param {number} n @param {string} noun */
function count(n, noun) {
  return `${n} ${noun}${n === 1 ? "" : "s"}`;
}

const NOTHING_FOUND = "Nothing found for this word. Type it yourself, or check the spelling.";

/** When the last "autofill paused" answer said definition autofill resumes. */
let resumesAt = "";

/**
 * AC-18: the resume time -- the next 00:00 UTC -- in the partner's own time.
 * @param {string} at
 */
function resumeWhen(at) {
  const date = new Date(at);
  if (Number.isNaN(date.getTime())) return "tomorrow";
  const time = date.toLocaleTimeString([], { hour: "numeric", minute: "2-digit" });
  return `${date.toDateString() === new Date().toDateString() ? "today" : "tomorrow"} at ${time}`;
}

/**
 * A lightning can fill this cell: it is empty and settled, and its row is on
 * the page with a word to look up.
 * @param {Cell} cell
 */
function fillable(cell) {
  return (
    !cell.busy &&
    cell.status === "idle" &&
    read(cell).trim() === "" &&
    cell.saved === "" &&
    !cell.row.pendingDelete &&
    state.rows.has(cell.row.id) &&
    read(cell.row.cells.word).trim() !== ""
  );
}

/**
 * US-08: a cell's lightning, from a tap.
 * @param {Cell} cell
 */
async function fillOne(cell) {
  if (state.gone || cell.busy || cell.field === "word") return;
  if (read(cell.row.cells.word).trim() === "") {
    show(cell, "notice", "Type the word first, then the lightning can fill this.");
    return;
  }
  await fill(cell);
}

/**
 * Fills one cell from its lightning, showing it is working meanwhile. Resolves
 * "filled"; "nothing" (the cell stays empty, AC-17); "skipped" (it got text
 * meanwhile, which stays); "paused" (definition autofill is used up today,
 * AC-18, AC-18b) or "failed" -- where a column run stops.
 * @param {Cell} cell
 * @returns {Promise<Fill | "skipped">}
 */
async function fill(cell) {
  cell.busy = true;
  cell.td.classList.add("working");
  cell.bolt?.setAttribute("aria-busy", "true");
  try {
    // A save of this row still in flight first: the lookup needs its word stored.
    while (rowBusy(cell.row)) await sleep(50);
    cell.busy = false;
    if (!fillable(cell)) return "skipped";
    cell.busy = true;
    if (cell.td.dataset.state === "notice") show(cell, "idle");
    return cell.field === "translation" ? await fillTranslation(cell) : await fillDefinition(cell);
  } finally {
    cell.busy = false;
    cell.td.classList.remove("working");
    cell.bolt?.removeAttribute("aria-busy");
    releaseHeld(cell);
  }
}

/**
 * Asks the translation endpoint from this browser (ADR-0007). Resolves the
 * translation; "" when there is none -- the endpoint echoes a word it cannot
 * translate (T1) -- or null when it did not answer.
 * @param {string} word
 * @returns {Promise<string | null>}
 */
async function translate(word) {
  try {
    const res = await fetch(TRANSLATE_URL + encodeURIComponent(word));
    if (!res.ok) return null;
    /** @type {unknown} */
    const data = await res.json();
    // As lib/core/services/translate_response_parser.dart: join the first element of each segment.
    const segments = Array.isArray(data) ? data[0] : null;
    if (!Array.isArray(segments)) return "";
    const text = segments
      .map((segment) => (Array.isArray(segment) && typeof segment[0] === "string" ? segment[0] : ""))
      .join("")
      .trim();
    return text.toLowerCase() === word.toLowerCase() ? "" : text;
  } catch {
    return null;
  }
}

/**
 * A translation lightning: not metered (spec §1). The found text is saved like
 * the partner's own edit.
 * @param {Cell} cell
 * @returns {Promise<Fill | "skipped">}
 */
async function fillTranslation(cell) {
  const found = await translate(read(cell.row.cells.word).trim());
  if (found === null) {
    show(cell, "notice", "The translation service is not answering. Try again later, or type the translation.");
    return "failed";
  }
  if (found === "") {
    show(cell, "notice", NOTHING_FOUND);
    return "nothing";
  }
  // Typed in, or filled by another partner, while the lookup ran: that stays.
  if (read(cell) !== "" || cell.saved !== "" || cell.status !== "idle" || cell.held) return "skipped";
  setText(cell, found);
  await save(cell);
  if (cell.status === "idle") return "filled";
  return cell.status === "conflict" ? "skipped" : "failed";
}

/**
 * A definition lightning: the Worker looks it up and saves it, counting one
 * unit of this page's allowance (T9).
 * @param {Cell} cell
 * @returns {Promise<Fill | "skipped">}
 */
async function fillDefinition(cell) {
  const row = cell.row;
  if (row.phase !== "live" || isDirty(row.cells.word)) {
    show(cell, "notice", "The word of this row is not saved yet. Save it, then try again.");
    return "failed";
  }
  const { status, body } = await api("/define", { rowId: row.id });
  if ((status === 200 || status === 409) && typeof body.value === "string" && typeof body.rev === "number") {
    // Filled, or it got text meanwhile (409), which stays (AC-19). Shown like
    // another partner's save, so text typed in the cell meanwhile is not lost.
    cell.busy = false;
    const shown = applyRemote(cell, { value: body.value, rev: body.rev });
    if (status === 409) return "skipped";
    if (shown) show(cell, "saved");
    return "filled";
  }
  if (status === 429 && body.code === "autofill_paused") {
    resumesAt = body.resumesAt ?? "";
    show(
      cell,
      "notice",
      `Definition autofill is paused. It resumes ${resumeWhen(resumesAt)}. You can still type the definition.`
    );
    return "paused";
  }
  if (status === 422 && body.code === "nothing_found") {
    show(cell, "notice", NOTHING_FOUND);
    return "nothing";
  }
  if (status === 404 && body.code === "gone") {
    listGone();
    return "failed";
  }
  show(
    cell,
    "notice",
    status === 0 ? "There is no connection. Try again in a moment." : body.error ?? "Something went wrong. Try again in a moment."
  );
  return "failed";
}

/**
 * US-09: a column's lightning fills its empty cells one by one in table order,
 * never a filled one, each saved as its own request, at most three a second
 * (AC-35). A definition run stops when the allowance runs out (AC-20); either
 * way the page reports what was filled and what found nothing (AC-19).
 * @param {Field} field
 * @param {HTMLButtonElement} button
 */
async function fillColumn(field, button) {
  if (!tbody || state.gone || state.columnRuns.has(field)) return;
  const name = LABELS[field].toLowerCase();
  /** @type {Cell[]} */
  const cells = [];
  for (const tr of tbody.querySelectorAll("tr[data-row]")) {
    const row = state.rows.get(/** @type {HTMLElement} */ (tr).dataset.row ?? "");
    if (row && fillable(row.cells[field])) cells.push(row.cells[field]);
  }
  if (cells.length === 0) {
    toast(`There is no empty ${name} with a word to fill.`, NOTICE_MS);
    return;
  }
  state.columnRuns.add(field);
  button.setAttribute("aria-busy", "true");
  button.closest("th")?.classList.add("working");
  let filled = 0;
  let nothing = 0;
  /** @type {Fill | "done"} */
  let end = "done";
  let last = 0;
  try {
    for (const cell of cells) {
      if (state.gone) break;
      // Filled by someone, or typed in, since the run began: it stays.
      if (!fillable(cell)) continue;
      await sleep(Math.max(0, last + COLUMN_GAP_MS - Date.now()));
      last = Date.now();
      const result = await fill(cell);
      if (result === "filled") filled++;
      else if (result === "nothing") nothing++;
      else if (result === "paused" || result === "failed") {
        end = result;
        break;
      }
    }
  } finally {
    state.columnRuns.delete(field);
    button.removeAttribute("aria-busy");
    button.closest("th")?.classList.remove("working");
  }
  const looked = filled + nothing;
  const summary = `${filled} filled, ${nothing} found nothing`;
  if (end === "paused") {
    const when = `Definition autofill resumes ${resumeWhen(resumesAt)}.`;
    toast(
      looked === 0
        ? `Definition autofill is paused: today's allowance is used up. ${when}`
        : `The autofill allowance ran out after ${count(looked, "lookup")}: ${summary}. ${when}`,
      REPORT_MS
    );
  } else if (end === "failed") {
    toast(`${LABELS[field]} autofill stopped after ${count(looked, "lookup")}: ${summary}. The reason is beside the cell.`, REPORT_MS);
  } else {
    toast(`${LABELS[field]} autofill: ${summary}.`, REPORT_MS);
  }
}

/**
 * The column lightning in a header.
 * @param {Element} th
 * @param {Field} field
 */
function addColumnBolt(th, field) {
  const button = bolt(`Fill every empty ${LABELS[field].toLowerCase()}`);
  button.dataset.column = field;
  th.append(" ", button);
  return button;
}

/**
 * AC-21: a collapsed column opens on this page only, with empty cells and
 * their lightnings; other partners see it once a cell has text, and it is
 * collapsed again on reload while still empty. Text arriving in it opens it too.
 * @param {Field} field
 */
function openColumn(field) {
  if (!main || !main.classList.contains(`no-${field}`)) return null;
  main.classList.remove(`no-${field}`);
  const th = main.querySelector(`thead th.c-${field}`);
  if (!th) return null;
  th.replaceChildren(LABELS[field]);
  return addColumnBolt(th, field);
}

/**
 * The partner did something on the page: a tap, click, key, scroll or focus,
 * or their own save or autofill (ADR-0005). An idle page catches up at once.
 */
function active() {
  state.poll.lastActive = Date.now();
  if (state.poll.idle) resume();
}

/** Back from idle or a hidden tab: polling restarts with a catch-up poll. */
function resume() {
  state.poll.idle = false;
  state.poll.hint?.remove();
  state.poll.hint = null;
  pollNow();
}

/** Polls now, or right after the poll in flight answers. */
function pollNow() {
  window.clearTimeout(state.poll.timer);
  state.poll.timer = 0;
  if (state.poll.inFlight) {
    state.poll.again = true;
    return;
  }
  void poll();
}

/** The next poll in POLL_MS -- only while the page is visible and in use. */
function schedule() {
  window.clearTimeout(state.poll.timer);
  state.poll.timer = 0;
  if (state.gone || state.stale || state.poll.idle || document.visibilityState === "hidden") return;
  if (Date.now() - state.poll.lastActive >= IDLE_MS) {
    pauseUpdates();
    return;
  }
  state.poll.timer = window.setTimeout(pollNow, POLL_MS);
}

/** Five minutes without activity: no more polls until the partner is back (ADR-0005). */
function pauseUpdates() {
  state.poll.idle = true;
  if (!main || state.poll.hint) return;
  // A snackbar that stays until the partner is back (resume() removes it).
  const hint = document.createElement("div");
  hint.className = "toast paused-toast";
  hint.setAttribute("role", "status");
  const body = document.createElement("div");
  body.className = "toast-body";
  body.textContent = "Updates paused while you were away. Click or tap anywhere to see the latest changes.";
  hint.append(body);
  main.querySelector(".toasts")?.append(hint);
  state.poll.hint = hint;
}

async function poll() {
  if (state.gone || state.stale) return;
  state.poll.inFlight = true;
  try {
    const feed = await changes();
    if (feed) applyFeed(feed);
  } finally {
    state.poll.inFlight = false;
  }
  if (state.poll.again) {
    state.poll.again = false;
    void poll();
  } else {
    schedule();
  }
}

/**
 * Asks the change feed for everything since the cursor. No answer (offline, a
 * server error) is null: the next poll asks from the same revision again.
 * @returns {Promise<Feed | null>}
 */
async function changes() {
  try {
    const res = await fetch(`/s/${encodeURIComponent(state.session)}/changes?since=${state.rev}`, { cache: "no-store" });
    /** @type {Feed & Answer} */
    const body = await res.json();
    if (res.status === 404 && body.code === "gone") listGone();
    return res.ok && typeof body.rev === "number" ? body : null;
  } catch {
    return null;
  }
}

/**
 * Applies another partner's saves: changed cells, rows added or changed whole,
 * deleted rows and arrived photos. Cells in use hold their change (AC-12).
 * @param {Feed} feed
 */
function applyFeed(feed) {
  if (feed.reload) {
    republished();
    return;
  }
  /** @type {Set<Row>} */
  const changed = new Set();
  for (const change of feed.cells ?? []) {
    const row = state.rows.get(change.rowId);
    const cell = row?.cells[change.field];
    if (row && cell && applyRemote(cell, change)) changed.add(row);
  }
  for (const incoming of feed.rows ?? []) {
    const row = state.rows.get(incoming.rowId);
    if (!row) {
      insertRow(incoming);
      continue;
    }
    for (const field of FIELDS) {
      if (applyRemote(row.cells[field], { value: incoming[field], rev: incoming.revs[field] })) changed.add(row);
    }
  }
  for (const tombstone of feed.deleted ?? []) {
    const row = state.rows.get(tombstone.rowId);
    if (row) removedElsewhere(row);
  }
  for (const source of feed.sources ?? []) photoArrived(source.id);
  for (const row of changed) flash(row);
  if (feed.rev > state.rev) state.rev = feed.rev;
}

/**
 * A row another partner added: built from the blank row and placed after the
 * stored rows, before any this page added and has not stored yet.
 * @param {FeedRow} incoming
 */
function insertRow(incoming) {
  if (!tbody || !blankRow) return;
  const tr = /** @type {HTMLTableRowElement} */ (
    /** @type {DocumentFragment} */ (blankRow.content.cloneNode(true)).firstElementChild
  );
  tr.dataset.row = incoming.rowId;
  // adoptRow highlights it when its photo is on display.
  if (incoming.sourceId !== null) tr.dataset.source = incoming.sourceId;
  for (const field of FIELDS) {
    const td = /** @type {HTMLTableCellElement} */ (tr.querySelector(`td[data-field="${field}"]`));
    td.dataset.rev = String(incoming.revs[field]);
    /** @type {HTMLElement} */ (td.querySelector(".v")).textContent = incoming[field];
  }
  const local = Array.from(tbody.rows).find(
    (other) => state.rows.get(other.dataset.row ?? "")?.phase !== "live"
  );
  tbody.insertBefore(tr, local ?? null);
  const row = adoptRow(tr);
  wordChanged(row.cells.word);
  for (const field of FIELDS) if (incoming[field] !== "") openColumn(field);
  flash(row);
}

/**
 * Another partner deleted this row, and the Worker took it: it goes here too.
 * Someone typing in it is told, so the text does not vanish unnoticed.
 * @param {Row} row
 */
function removedElsewhere(row) {
  const typing = !row.pendingDelete && FIELDS.some((field) => read(row.cells[field]) !== row.cells[field].saved);
  // Its own Undo, if one is running, has nothing left to send.
  row.pendingDelete = false;
  const word = clip(read(row.cells.word));
  dropRow(row);
  if (typing) toast(`Someone else deleted the row you were editing${word ? `: ${word}` : ""}.`, NOTICE_MS);
}

/**
 * AC-37: a photo whose bytes arrived after the page was rendered. Its
 * placeholder in the pager, and its thumbnail on the photo button, become it.
 * @param {string} id
 */
function photoArrived(id) {
  if (!main) return;
  const slides = Array.from(main.querySelectorAll(".photos .slide"));
  const index = slides.findIndex((slide) => /** @type {HTMLElement} */ (slide).dataset.source === id);
  const placeholder = index >= 0 ? slides[index].querySelector(".placeholder") : null;
  if (!placeholder) return;
  const src = `/s/${encodeURIComponent(state.session)}/sources/${encodeURIComponent(id)}`;
  const img = document.createElement("img");
  img.src = src;
  img.alt = `Source photo ${index + 1} of ${slides.length}`;
  img.loading = "lazy";
  placeholder.replaceWith(img);
  const thumb = main.querySelectorAll(".photo-button .thumb")[index];
  if (thumb instanceof HTMLSpanElement) {
    const picture = document.createElement("img");
    picture.className = "thumb";
    picture.src = src;
    picture.alt = "";
    thumb.replaceWith(picture);
  }
  // The open dialog shows it too.
  const shown = main.querySelectorAll(".dialog-slide")[index]?.querySelector(".placeholder");
  if (shown) shown.replaceWith(img.cloneNode());
}

/**
 * AC-05, AC-06: a row is highlighted while the photo it was recognised from is
 * on display. Only a recognised row has `data-source`, so a typed row and one
 * added on the page never are; an edit leaves `data-source` alone (AC-34).
 * @param {HTMLTableRowElement} tr
 */
function markFromPhoto(tr) {
  const source = tr.dataset.source;
  tr.classList.toggle("from-photo", source !== undefined && source === state.photo.source);
}

/**
 * Highlights the rows of the photo on display. After a swipe, when none of
 * them is on screen, the table scrolls to the first (AC-05) -- in the wide
 * layout only, where the pager is.
 * @param {boolean} scroll
 */
function highlightRows(scroll) {
  if (!tbody) return;
  for (const row of state.rows.values()) markFromPhoto(row.tr);
  if (!scroll || !WIDE.matches) return;
  const rows = Array.from(tbody.querySelectorAll("tr.from-photo:not(.pending-delete)"));
  if (rows.length === 0) return;
  // The sticky header hides the top of the viewport.
  const top = main?.querySelector("thead")?.getBoundingClientRect().height ?? 0;
  const visible = rows.some((tr) => {
    const box = tr.getBoundingClientRect();
    return box.bottom > top && box.top < window.innerHeight;
  });
  if (!visible) rows[0].scrollIntoView({ block: "center", behavior: REDUCED_MOTION.matches ? "auto" : "smooth" });
}

/** The pager's slides, in order. */
function slides() {
  return /** @type {HTMLElement[]} */ (Array.from(main?.querySelectorAll(".photos .slide") ?? []));
}

/**
 * Puts photo `index` on display in the pager: its "N of M" is under it, the
 * arrows stop at the ends, and its rows are highlighted. `move` scrolls the
 * track there (an arrow or a key); a swipe has already put it there.
 * @param {number} index
 * @param {boolean} move
 */
function showPhoto(index, move) {
  const all = slides();
  if (all.length === 0) return;
  const target = Math.max(0, Math.min(all.length - 1, index));
  const track = /** @type {HTMLElement | null} */ (main?.querySelector(".pager-track") ?? null);
  if (move && track) {
    // Slides are narrower than the track (the next one peeks in), so scroll by their offsets.
    const left = all[target].offsetLeft - all[0].offsetLeft;
    track.scrollTo({ left, behavior: REDUCED_MOTION.matches ? "auto" : "smooth" });
  }
  const prev = /** @type {HTMLButtonElement | null} */ (main?.querySelector('[data-pager="prev"]') ?? null);
  const next = /** @type {HTMLButtonElement | null} */ (main?.querySelector('[data-pager="next"]') ?? null);
  if (prev) prev.disabled = target === 0;
  if (next) next.disabled = target === all.length - 1;
  if (target === state.photo.index) return;
  state.photo.index = target;
  state.photo.source = all[target].dataset.source ?? null;
  highlightRows(true);
}

/**
 * The slide the track has snapped to: the one whose start is nearest its
 * scroll position, or the last one once the track is scrolled to its end
 * (the last slide cannot reach the start while the one before it peeks).
 * @param {HTMLElement} track
 */
function slideAt(track) {
  const all = slides();
  if (all.length === 0) return 0;
  if (track.scrollLeft >= track.scrollWidth - track.clientWidth - 1) return all.length - 1;
  /** @param {HTMLElement} slide */
  const distance = (slide) => Math.abs(slide.offsetLeft - all[0].offsetLeft - track.scrollLeft);
  let best = 0;
  all.forEach((slide, i) => {
    if (distance(slide) < distance(all[best])) best = i;
  });
  return best;
}

/** @param {HTMLElement} photos the pager, `aside.photos` */
function wirePager(photos) {
  const track = /** @type {HTMLElement | null} */ (photos.querySelector(".pager-track"));
  const nav = /** @type {HTMLElement | null} */ (photos.querySelector(".pager-nav"));
  if (!track) return;
  if (nav && slides().length > 1) nav.hidden = false;
  showPhoto(0, false);
  // A swipe (or a trackpad) scrolls the track; the photo it snaps to is the one on display.
  track.addEventListener(
    "scroll",
    () => {
      window.clearTimeout(state.photo.settle);
      state.photo.settle = window.setTimeout(() => {
        if (track.clientWidth > 0) showPhoto(slideAt(track), false);
      }, SETTLE_MS);
    },
    { passive: true }
  );
  track.addEventListener("keydown", (event) => {
    if (event.key !== "ArrowLeft" && event.key !== "ArrowRight") return;
    event.preventDefault();
    showPhoto(state.photo.index + (event.key === "ArrowRight" ? 1 : -1), true);
  });
  nav?.addEventListener("click", (event) => {
    const button = event.target instanceof Element ? event.target.closest("[data-pager]") : null;
    if (button instanceof HTMLElement) {
      showPhoto(state.photo.index + (button.dataset.pager === "next" ? 1 : -1), true);
    }
  });
}

/**
 * AC-07: the phone's photo button opens a full-screen dialog on the first
 * photo. Its photos are the pager's, copied in as it opens, so a photo that
 * arrived by poll is there too. Closing returns to the table where it was.
 * @param {HTMLDialogElement} dialog
 */
function openDialog(dialog) {
  const strip = /** @type {HTMLElement} */ (dialog.querySelector(".dialog-strip"));
  const all = slides();
  strip.replaceChildren(
    ...all.map((slide) => {
      const figure = document.createElement("figure");
      figure.className = "dialog-slide";
      const picture = slide.querySelector("img, .placeholder, .set-card");
      if (picture) {
        const copy = /** @type {HTMLElement} */ (picture.cloneNode(true));
        // Off-screen in the strip, a lazy image would wait for a swipe to load.
        if (copy instanceof HTMLImageElement) copy.loading = "eager";
        copy.draggable = false;
        figure.append(copy);
      }
      return figure;
    })
  );
  const scroller = main?.querySelector(".table-scroll");
  state.dialog.scrollX = window.scrollX;
  state.dialog.scrollY = window.scrollY;
  state.dialog.tableLeft = scroller?.scrollLeft ?? 0;
  state.dialog.tableTop = scroller?.scrollTop ?? 0;
  for (const button of dialog.querySelectorAll('[data-dialog="prev"], [data-dialog="next"]')) {
    /** @type {HTMLElement} */ (button).hidden = all.length < 2;
  }
  showInDialog(dialog, 0, false);
  document.documentElement.classList.add("dialog-open");
  dialog.showModal();
  /** @type {HTMLElement | null} */ (dialog.querySelector('[data-dialog="close"]'))?.focus();
}

/**
 * The dialog closed (its × or Escape): the table is back as it was, at the
 * same scroll position (AC-07).
 * @param {HTMLDialogElement} dialog
 */
function dialogClosed(dialog) {
  document.documentElement.classList.remove("dialog-open");
  window.scrollTo(state.dialog.scrollX, state.dialog.scrollY);
  const scroller = main?.querySelector(".table-scroll");
  if (scroller) {
    scroller.scrollLeft = state.dialog.tableLeft;
    scroller.scrollTop = state.dialog.tableTop;
  }
  gesture.pointers.clear();
  /** @type {HTMLElement} */ (dialog.querySelector(".dialog-strip")).replaceChildren();
}

/**
 * Shows photo `index` in the dialog, unzoomed, with its "N of M".
 * @param {HTMLDialogElement} dialog
 * @param {number} index
 * @param {boolean} animate
 */
function showInDialog(dialog, index, animate) {
  const strip = /** @type {HTMLElement} */ (dialog.querySelector(".dialog-strip"));
  const total = strip.children.length;
  zoomTo(dialog, 1, 0, 0);
  state.dialog.index = Math.max(0, Math.min(total - 1, index));
  strip.classList.toggle("dragging", !animate);
  strip.style.transform = `translateX(${-100 * state.dialog.index}%)`;
  const count = dialog.querySelector(".dialog-count");
  if (count) count.textContent = total > 0 ? `${state.dialog.index + 1} of ${total}` : "";
  const prev = /** @type {HTMLButtonElement | null} */ (dialog.querySelector('[data-dialog="prev"]'));
  const next = /** @type {HTMLButtonElement | null} */ (dialog.querySelector('[data-dialog="next"]'));
  if (prev) prev.disabled = state.dialog.index === 0;
  if (next) next.disabled = state.dialog.index >= total - 1;
}

/** @param {HTMLDialogElement} dialog */
function dialogImage(dialog) {
  const slide = dialog.querySelectorAll(".dialog-slide")[state.dialog.index];
  return /** @type {HTMLImageElement | null} */ (slide?.querySelector("img") ?? null);
}

/**
 * Zooms the shown photo to `scale`, moved by `x`/`y`, kept so it always covers
 * the middle of the screen (it cannot be dragged off). A CSS transform only;
 * set through the style property, which the CSP allows.
 * @param {HTMLDialogElement} dialog
 * @param {number} scale
 * @param {number} x
 * @param {number} y
 */
function zoomTo(dialog, scale, x, y) {
  const img = dialogImage(dialog);
  gesture.scale = Math.max(1, Math.min(MAX_ZOOM, scale));
  if (!img || gesture.scale === 1) {
    gesture.x = 0;
    gesture.y = 0;
  } else {
    const slide = /** @type {HTMLElement} */ (img.parentElement);
    gesture.x = clampPan(x, img.offsetLeft, img.offsetWidth, slide.clientWidth, gesture.scale);
    gesture.y = clampPan(y, img.offsetTop, img.offsetHeight, slide.clientHeight, gesture.scale);
  }
  if (img) img.style.transform = `translate(${gesture.x}px, ${gesture.y}px) scale(${gesture.scale})`;
}

/**
 * The pan along one axis that keeps a zoomed photo's edges outside the view,
 * or centred when it is still narrower than the view.
 * @param {number} pan @param {number} offset @param {number} size @param {number} view @param {number} scale
 */
function clampPan(pan, offset, size, view, scale) {
  const scaled = size * scale;
  if (scaled <= view) return (view - scaled) / 2 - offset;
  return Math.min(-offset, Math.max(view - offset - scaled, pan));
}

/**
 * A point on screen measured from the shown photo's untransformed box, the
 * frame its `translate` works in (it is centred in its slide).
 * @param {HTMLDialogElement} dialog @param {{ x: number, y: number }} point
 */
function inSlide(dialog, point) {
  const box = /** @type {HTMLElement} */ (dialog.querySelector(".dialog-view")).getBoundingClientRect();
  const img = dialogImage(dialog);
  return { x: point.x - box.left - (img?.offsetLeft ?? 0), y: point.y - box.top - (img?.offsetTop ?? 0) };
}

/** @param {HTMLDialogElement} dialog */
function pinchStart(dialog) {
  const [a, b] = Array.from(gesture.pointers.values());
  gesture.startScale = gesture.scale;
  gesture.startX = gesture.x;
  gesture.startY = gesture.y;
  if (b) {
    gesture.startDist = Math.hypot(a.x - b.x, a.y - b.y);
    gesture.startMid = inSlide(dialog, { x: (a.x + b.x) / 2, y: (a.y + b.y) / 2 });
  } else if (a) {
    gesture.startMid = inSlide(dialog, a);
  }
}

/**
 * Swipe between photos, pinch or double-tap to zoom, drag a zoomed photo --
 * with pointer events and CSS transforms only (no library, sad §2). The view
 * has `touch-action: none`, so the browser leaves every touch to this.
 * @param {HTMLDialogElement} dialog
 */
function wireDialogGestures(dialog) {
  const view = /** @type {HTMLElement} */ (dialog.querySelector(".dialog-view"));
  const strip = /** @type {HTMLElement} */ (dialog.querySelector(".dialog-strip"));

  view.addEventListener("pointerdown", (event) => {
    if (event.pointerType === "mouse" && event.button !== 0) return;
    // A set page's link is tapped, not swiped: capture would take its click away.
    if (event.target instanceof Element && event.target.closest("a")) return;
    view.setPointerCapture(event.pointerId);
    gesture.pointers.set(event.pointerId, { x: event.clientX, y: event.clientY });
    if (gesture.pointers.size === 1) {
      gesture.downX = event.clientX;
      gesture.downAt = event.timeStamp;
      gesture.moved = false;
      gesture.pinched = false;
      strip.classList.add("dragging");
    } else {
      gesture.pinched = true;
    }
    pinchStart(dialog);
  });

  view.addEventListener("pointermove", (event) => {
    const point = gesture.pointers.get(event.pointerId);
    if (!point) return;
    point.x = event.clientX;
    point.y = event.clientY;
    const [a, b] = Array.from(gesture.pointers.values());
    if (b) {
      // Pinch: the point between the fingers stays under them.
      const mid = inSlide(dialog, { x: (a.x + b.x) / 2, y: (a.y + b.y) / 2 });
      const scale = Math.max(1, Math.min(MAX_ZOOM, (gesture.startScale * Math.hypot(a.x - b.x, a.y - b.y)) / gesture.startDist));
      const ratio = scale / gesture.startScale;
      zoomTo(
        dialog,
        scale,
        mid.x - (gesture.startMid.x - gesture.startX) * ratio,
        mid.y - (gesture.startMid.y - gesture.startY) * ratio
      );
      return;
    }
    const at = inSlide(dialog, a);
    const dx = at.x - gesture.startMid.x;
    const dy = at.y - gesture.startMid.y;
    if (!gesture.moved && Math.hypot(dx, dy) < TAP_SLOP) return;
    gesture.moved = true;
    if (gesture.scale > 1) {
      zoomTo(dialog, gesture.scale, gesture.startX + dx, gesture.startY + dy);
    } else if (!gesture.pinched) {
      // Unzoomed: the strip follows the finger, with some give at either end.
      const last = strip.children.length - 1;
      const edge = (state.dialog.index === 0 && dx > 0) || (state.dialog.index === last && dx < 0);
      strip.style.transform = `translateX(calc(${-100 * state.dialog.index}% + ${edge ? dx / 3 : dx}px))`;
    }
  });

  /** @param {PointerEvent} event */
  const up = (event) => {
    if (!gesture.pointers.delete(event.pointerId)) return;
    if (gesture.pointers.size > 0) {
      // One finger left of a pinch: it drags from here.
      pinchStart(dialog);
      return;
    }
    const dx = event.clientX - gesture.downX;
    const speed = Math.abs(dx) / Math.max(1, event.timeStamp - gesture.downAt);
    if (event.type === "pointercancel") {
      showInDialog(dialog, state.dialog.index, true);
    } else if (!gesture.moved && !gesture.pinched) {
      // A double tap zooms in on that point, or back out.
      if (event.timeStamp - gesture.lastTap < DOUBLE_TAP_MS) {
        gesture.lastTap = 0;
        const at = inSlide(dialog, { x: event.clientX, y: event.clientY });
        if (gesture.scale > 1) {
          zoomTo(dialog, 1, 0, 0);
        } else {
          zoomTo(dialog, TAP_ZOOM, at.x - (at.x - gesture.x) * TAP_ZOOM, at.y - (at.y - gesture.y) * TAP_ZOOM);
        }
      } else {
        gesture.lastTap = event.timeStamp;
      }
    } else if (gesture.scale === 1 && !gesture.pinched) {
      const turn = Math.abs(dx) > view.clientWidth * SWIPE_SHARE || speed > SWIPE_SPEED;
      showInDialog(dialog, state.dialog.index + (turn ? (dx < 0 ? 1 : -1) : 0), true);
      return;
    }
    strip.classList.remove("dragging");
  };
  view.addEventListener("pointerup", up);
  view.addEventListener("pointercancel", up);
}

/** @param {HTMLDialogElement} dialog @param {HTMLElement} button the photo button */
function wireDialog(dialog, button) {
  button.addEventListener("click", () => openDialog(dialog));
  dialog.addEventListener("close", () => dialogClosed(dialog));
  dialog.addEventListener("click", (event) => {
    const control = event.target instanceof Element ? event.target.closest("[data-dialog]") : null;
    if (!(control instanceof HTMLElement)) return;
    if (control.dataset.dialog === "close") {
      dialog.close();
    } else {
      showInDialog(dialog, state.dialog.index + (control.dataset.dialog === "next" ? 1 : -1), true);
    }
  });
  dialog.addEventListener("keydown", (event) => {
    if (event.key !== "ArrowLeft" && event.key !== "ArrowRight") return;
    event.preventDefault();
    showInDialog(dialog, state.dialog.index + (event.key === "ArrowRight" ? 1 : -1), true);
  });
  wireDialogGestures(dialog);
}

/**
 * ADR-0008: the learner republished the list under this link, so its rows and
 * revisions are a new version. The page loads it at once when it holds nothing
 * unsaved; otherwise it says so and leaves the partner's text where it is.
 */
function republished() {
  if (state.stale || !main) return;
  state.stale = true;
  if (unsavedCells().length === 0) {
    window.location.reload();
    return;
  }
  const banner = document.createElement("p");
  banner.className = "banner";
  banner.setAttribute("role", "alert");
  banner.textContent =
    "The learner published a new version of this list. Copy any text you have not saved, then reload the page.";
  main.prepend(banner);
}

/** @param {HTMLElement} el @param {Field} field */
function makeEditable(el, field) {
  el.contentEditable = PLAINTEXT_ONLY ? "plaintext-only" : "true";
  el.setAttribute("role", "textbox");
  el.setAttribute("aria-label", LABELS[field]);
  if (field === "definition") el.setAttribute("aria-multiline", "true");
}

/**
 * Reads a rendered row into the state and makes its cells editable.
 * @param {HTMLTableRowElement} tr
 * @param {Row["phase"]} [phase]
 * @returns {Row}
 */
function adoptRow(tr, phase = "live") {
  const row = /** @type {Row} */ ({ id: tr.dataset.row ?? "", tr, cells: {}, phase, pendingDelete: false });
  markFromPhoto(tr);
  for (const field of FIELDS) {
    const td = /** @type {HTMLTableCellElement} */ (tr.querySelector(`td[data-field="${field}"]`));
    const el = /** @type {HTMLElement} */ (td.querySelector(".v"));
    makeEditable(el, field);
    /** @type {Cell} */
    const cell = {
      row,
      field,
      td,
      el,
      note: null,
      bolt: null,
      saved: el.textContent ?? "",
      rev: Number(td.dataset.rev ?? 0),
      status: "idle",
      again: false,
      theirs: null,
      held: null,
      busy: false,
      timer: 0,
    };
    if (field !== "word") {
      cell.bolt = bolt(`Fill this ${LABELS[field].toLowerCase()}`);
      td.prepend(cell.bolt);
    }
    markFilled(cell);
    row.cells[field] = cell;
  }
  state.rows.set(row.id, row);
  return row;
}

/**
 * A lightning button (US-08, US-09): the app's electric bolt.
 * @param {string} label
 */
function bolt(label) {
  const button = document.createElement("button");
  button.type = "button";
  button.className = "bolt";
  button.setAttribute("aria-label", label);
  const svg = document.createElementNS(SVG_NS, "svg");
  svg.setAttribute("viewBox", "0 0 24 24");
  svg.setAttribute("aria-hidden", "true");
  const path = document.createElementNS(SVG_NS, "path");
  path.setAttribute("d", BOLT_PATH);
  svg.append(path);
  button.append(svg);
  return button;
}

/**
 * The cell an event happened in, if it is one of the table's editable cells.
 * @param {EventTarget | null} target
 * @returns {Cell | null}
 */
function cellAt(target) {
  if (!(target instanceof Element)) return null;
  const td = /** @type {HTMLTableCellElement | null} */ (target.closest("td[data-field]"));
  const tr = /** @type {HTMLTableRowElement | null} */ (td?.closest("tr[data-row]") ?? null);
  const row = tr ? state.rows.get(tr.dataset.row ?? "") : undefined;
  if (!td || !row) return null;
  return row.cells[/** @type {Field} */ (td.dataset.field)] ?? null;
}

/** @param {Cell} cell */
function isDirty(cell) {
  return cell.status !== "idle" || read(cell) !== cell.saved;
}

/** @param {HTMLElement} el */
function focusAtEnd(el) {
  el.focus();
  const selection = window.getSelection();
  selection?.selectAllChildren(el);
  selection?.collapseToEnd();
}

/** @param {HTMLTableSectionElement} tbody */
function wireTable(tbody) {
  // Leaving a cell saves it (AC-09).
  tbody.addEventListener("focusout", (event) => {
    const cell = cellAt(event.target);
    if (!cell || event.target !== cell.el) return;
    normalise(cell);
    void save(cell);
  });
  tbody.addEventListener("keydown", (event) => {
    const cell = cellAt(event.target);
    if (!cell || event.target !== cell.el || event.isComposing) return;
    // A word or a translation is one line: Enter finishes it. A definition
    // keeps its line break between definition and example.
    if (event.key === "Enter" && cell.field !== "definition") {
      event.preventDefault();
      cell.el.blur();
    }
  });
  // A tap on a cell's padding still lands in its text.
  tbody.addEventListener("click", (event) => {
    const target = /** @type {Element} */ (event.target);
    const del = target instanceof Element ? target.closest(".del") : null;
    if (del) {
      const row = state.rows.get(/** @type {HTMLElement} */ (del.closest("tr[data-row]"))?.dataset.row ?? "");
      if (row) deleteRow(row);
      return;
    }
    const cell = cellAt(event.target);
    if (cell && target instanceof Element && target.closest(".bolt")) {
      void fillOne(cell);
      return;
    }
    if (cell && event.target === cell.td && !state.gone) focusAtEnd(cell.el);
  });
  // Typing hides the lightning; a note from it goes once the partner is back in the cell.
  tbody.addEventListener("input", (event) => {
    const cell = cellAt(event.target);
    if (cell && event.target === cell.el) markFilled(cell);
  });
  tbody.addEventListener("focusin", (event) => {
    const cell = cellAt(event.target);
    if (cell && event.target === cell.el && cell.status === "idle" && cell.td.dataset.state === "notice") {
      show(cell, "idle");
    }
  });
  if (!PLAINTEXT_ONLY) {
    // Without plaintext-only a paste would bring its formatting along.
    tbody.addEventListener("paste", (event) => {
      if (!cellAt(event.target)) return;
      event.preventDefault();
      const text = event.clipboardData?.getData("text/plain") ?? "";
      document.execCommand("insertText", false, text);
    });
  }
}

/** Every cell with text the Worker does not have yet. */
function unsavedCells() {
  /** @type {Cell[]} */
  const cells = [];
  for (const row of state.rows.values()) {
    if (row.pendingDelete) continue;
    for (const field of FIELDS) if (isDirty(row.cells[field])) cells.push(row.cells[field]);
  }
  return cells;
}

if (main) {
  if (tbody) {
    for (const tr of tbody.querySelectorAll("tr[data-row]")) adoptRow(/** @type {HTMLTableRowElement} */ (tr));
    wireTable(tbody);
    const add = main.querySelector(".add-row .add");
    if (blankRow && add) add.addEventListener("click", () => addBlankRow(tbody, blankRow));

    // The photo pager (wide) and the photo dialog (phone), when there are photos.
    const photos = /** @type {HTMLElement | null} */ (main.querySelector("aside.photos"));
    if (photos) wirePager(photos);
    const dialog = main.querySelector("dialog.photo-dialog");
    const photoButton = main.querySelector(".photo-button");
    if (dialog instanceof HTMLDialogElement && photoButton instanceof HTMLElement) wireDialog(dialog, photoButton);

    // The column lightnings (US-09) and a collapsed column's add control (US-10).
    const thead = main.querySelector("thead");
    for (const field of /** @type {Field[]} */ (["translation", "definition"])) {
      const th = thead?.querySelector(`th.c-${field}`);
      if (th && !main.classList.contains(`no-${field}`)) addColumnBolt(th, field);
    }
    thead?.addEventListener("click", (event) => {
      const target = event.target instanceof Element ? event.target : null;
      const open = /** @type {HTMLElement | null} */ (target?.closest(".add-col") ?? null);
      if (open) {
        openColumn(/** @type {Field} */ (open.dataset.open))?.focus();
        return;
      }
      const column = /** @type {HTMLButtonElement | null} */ (target?.closest(".bolt") ?? null);
      if (column) void fillColumn(/** @type {Field} */ (column.dataset.column), column);
    });
  }

  // What counts as using the page (ADR-0005). Scroll does not bubble: capture
  // also catches the phone layout's scrolling table.
  for (const type of ["pointerdown", "keydown", "focusin"]) document.addEventListener(type, active, true);
  document.addEventListener("scroll", active, { capture: true, passive: true });

  // Switching apps on a phone may be the last thing the partner does: save the
  // cell they are in as the page is hidden. A hidden tab does not poll; shown
  // again, it catches up at once.
  document.addEventListener("visibilitychange", () => {
    if (document.visibilityState !== "hidden") {
      state.poll.lastActive = Date.now();
      resume();
      return;
    }
    window.clearTimeout(state.poll.timer);
    state.poll.timer = 0;
    const cell = cellAt(document.activeElement);
    if (cell) void save(cell);
  });
  schedule();
  // Back online: try again what the connection dropped.
  window.addEventListener("online", () => {
    for (const cell of unsavedCells()) if (cell.status === "unsaved") void save(cell);
  });
  window.addEventListener("beforeunload", (event) => {
    if (state.gone || unsavedCells().length === 0) return;
    event.preventDefault();
    event.returnValue = "";
  });
}
