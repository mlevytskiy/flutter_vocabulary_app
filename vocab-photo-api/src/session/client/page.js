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
 */

/** @typedef {"word" | "translation" | "definition"} Field */

/**
 * @typedef {object} Cell
 * @property {Row} row
 * @property {Field} field
 * @property {HTMLTableCellElement} td
 * @property {HTMLElement} el the editable text, `.v`
 * @property {HTMLElement | null} note the status line under the text, made when first needed
 * @property {string} saved the value as last saved (or as the page was loaded)
 * @property {number} rev the revision of `saved`
 * @property {"idle" | "saving" | "unsaved" | "conflict"} status
 * @property {boolean} again another save is wanted once the one in flight ends
 * @property {{ value: string, rev: number } | null} theirs the other value, during a conflict
 * @property {number} timer hides the "saved" confirmation
 */

/**
 * @typedef {object} Row
 * @property {string} id
 * @property {HTMLTableRowElement} tr
 * @property {Record<Field, Cell>} cells
 */

/**
 * The Worker's answer to a page write: `{ error, code, … }` on refusal (sad §8).
 * @typedef {{ error?: string, code?: string, rev?: number, value?: string, deleted?: boolean }} Answer
 */

/** @type {readonly Field[]} */
const FIELDS = ["word", "translation", "definition"];
/** @type {Record<Field, string>} */
const LABELS = { word: "Word", translation: "Translation", definition: "Definition" };
const SAVED_FOR_MS = 2000;

document.documentElement.classList.add("js");

const main = /** @type {HTMLElement | null} */ (document.querySelector("main[data-session]"));

const state = {
  session: main?.dataset.session ?? "",
  /** The highest session revision this page has seen (ADR-0005). */
  rev: Number(main?.dataset.rev ?? 0),
  /** @type {Map<string, Row>} */
  rows: new Map(),
  /** Set once the Worker says the list is gone: nothing more can be saved. */
  gone: false,
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

/** @param {number} rev */
function seen(rev) {
  if (rev > state.rev) state.rev = rev;
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
 * "conflict" with both values and the choice, or nothing.
 * @param {Cell} cell
 * @param {"idle" | "saving" | "saved" | "unsaved" | "conflict"} shown
 * @param {string} [message]
 */
function show(cell, shown, message = "") {
  window.clearTimeout(cell.timer);
  cell.status = shown === "saved" ? "idle" : shown;
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
    cell.el.textContent = theirs.value;
    wordChanged(cell);
    show(cell, "idle");
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
  seen(held.rev);
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
  if (cell.status === "saving") {
    cell.again = true;
    return;
  }
  const value = read(cell);
  if (value === cell.saved) {
    if (cell.status === "unsaved") show(cell, "idle");
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
  } else if (status === 404 && body.code === "gone") {
    listGone();
    show(cell, "unsaved", body.error ?? "");
  } else if (status === 0) {
    show(cell, "unsaved", "There is no connection. It is tried again when you leave the cell.");
  } else {
    // field_too_long / list_full (AC-10, AC-38), a deleted row, the write limit.
    show(cell, "unsaved", body.error ?? "Something went wrong. Try again in a moment.");
  }
  if (cell.again) {
    cell.again = false;
    void save(cell);
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
  for (const row of state.rows.values()) {
    for (const field of FIELDS) row.cells[field].el.contentEditable = "false";
  }
}

/** @param {HTMLElement} el @param {Field} field */
function makeEditable(el, field) {
  el.contentEditable = PLAINTEXT_ONLY ? "plaintext-only" : "true";
  el.setAttribute("role", "textbox");
  el.setAttribute("aria-label", LABELS[field]);
  if (field === "definition") el.setAttribute("aria-multiline", "true");
}

/**
 * Reads a server-rendered row into the state and makes its cells editable.
 * @param {HTMLTableRowElement} tr
 * @returns {Row}
 */
function adoptRow(tr) {
  const row = /** @type {Row} */ ({ id: tr.dataset.row ?? "", tr, cells: {} });
  for (const field of FIELDS) {
    const td = /** @type {HTMLTableCellElement} */ (tr.querySelector(`td[data-field="${field}"]`));
    const el = /** @type {HTMLElement} */ (td.querySelector(".v"));
    makeEditable(el, field);
    row.cells[field] = {
      row,
      field,
      td,
      el,
      note: null,
      saved: el.textContent ?? "",
      rev: Number(td.dataset.rev ?? 0),
      status: "idle",
      again: false,
      theirs: null,
      timer: 0,
    };
  }
  state.rows.set(row.id, row);
  return row;
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
    const cell = cellAt(event.target);
    if (cell && event.target === cell.td && !state.gone) focusAtEnd(cell.el);
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
    for (const field of FIELDS) if (isDirty(row.cells[field])) cells.push(row.cells[field]);
  }
  return cells;
}

if (main) {
  const tbody = main.querySelector("tbody");
  if (tbody) {
    for (const tr of tbody.querySelectorAll("tr[data-row]")) adoptRow(/** @type {HTMLTableRowElement} */ (tr));
    wireTable(tbody);
  }

  // Switching apps on a phone may be the last thing the partner does: save the
  // cell they are in as the page is hidden.
  document.addEventListener("visibilitychange", () => {
    if (document.visibilityState !== "hidden") return;
    const cell = cellAt(document.activeElement);
    if (cell) void save(cell);
  });
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
