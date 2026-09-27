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
 * @property {"new" | "adding" | "live"} phase "new": added by the plus button, not stored
 *   until a cell gets text; "adding": that first save is in flight; "live": the Worker has it
 * @property {boolean} pendingDelete hidden, with its Undo running (AC-15)
 */

/**
 * The Worker's answer to a page write: `{ error, code, … }` on refusal (sad §8);
 * a refused delete carries the row as it is now (`word`… and `revs`).
 * @typedef {{ error?: string, code?: string, rev?: number, value?: string, deleted?: boolean,
 *   word?: string, translation?: string, definition?: string, revs?: Record<Field, number> }} Answer
 */

/** @type {readonly Field[]} */
const FIELDS = ["word", "translation", "definition"];
/** @type {Record<Field, string>} */
const LABELS = { word: "Word", translation: "Translation", definition: "Definition" };
const SAVED_FOR_MS = 2000;
const UNDO_MS = 5000;
const NOTICE_MS = 6000;

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
  /** The most rows a session may hold (AC-14), rendered by the Worker. */
  maxRows: Number(main?.dataset.maxRows ?? 500),
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
  if (cell.status === "saving" || cell.row.phase === "adding") {
    cell.again = true;
    return;
  }
  const value = read(cell);
  if (value === cell.saved) {
    if (cell.status === "unsaved") show(cell, "idle");
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
  for (const row of state.rows.values()) {
    for (const field of FIELDS) row.cells[field].el.contentEditable = "false";
  }
}

/**
 * A short message at the bottom of the page, read out by screen readers
 * (`.toasts` is aria-live). Returns the toast so an action can be added.
 * @param {string} text
 * @param {number} ms how long it stays
 */
function toast(text, ms) {
  const box = main?.querySelector(".toasts");
  const el = document.createElement("div");
  el.className = "toast";
  const p = document.createElement("span");
  p.textContent = text;
  el.append(p);
  box?.append(el);
  const timer = window.setTimeout(() => el.remove(), ms);
  return { el, close: () => { window.clearTimeout(timer); el.remove(); } };
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
 * AC-15: the row disappears at once and an Undo stays for five seconds. Only
 * then is the delete sent, with the revision of every cell as this page knows
 * them; leaving the page before that deletes nothing.
 * @param {Row} row
 */
function deleteRow(row) {
  if (state.gone || row.pendingDelete) return;
  row.pendingDelete = true;
  row.tr.classList.add("pending-delete");
  const shown = toast("Row deleted.", UNDO_MS);
  const undo = document.createElement("button");
  undo.type = "button";
  undo.textContent = "Undo";
  shown.el.append(undo);
  const timer = window.setTimeout(() => void commitDelete(row), UNDO_MS);
  undo.addEventListener("click", () => {
    window.clearTimeout(timer);
    shown.close();
    row.pendingDelete = false;
    row.tr.classList.remove("pending-delete");
    /** @type {HTMLElement | null} */ (row.tr.querySelector(".del"))?.focus();
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
  while (rowBusy(row)) await new Promise((resolve) => window.setTimeout(resolve, 50));
  if (!row.pendingDelete) return;
  if (row.phase === "new") {
    dropRow(row);
    return;
  }
  /** @type {Record<Field, number>} */
  const revs = { word: row.cells.word.rev, translation: row.cells.translation.rev, definition: row.cells.definition.rev };
  const { status, body } = await api("/rows/delete", { rowId: row.id, revs });
  if (status === 200 || (status === 404 && body.code === "unknown_row")) {
    if (typeof body.rev === "number") seen(body.rev);
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
      if (cell.status === "idle" && read(cell) === cell.saved) {
        accept(cell, { value, rev });
        cell.el.textContent = value;
      } else if (value !== cell.saved) {
        cell.theirs = { value, rev };
        show(cell, "conflict");
      }
    }
    wordChanged(row.cells.word);
    row.tr.classList.remove("changed");
    void row.tr.offsetWidth; // restart the highlight
    row.tr.classList.add("changed");
    toast("Someone changed this row meanwhile, so it was not deleted.", NOTICE_MS);
  } else if (status === 404 && body.code === "gone") {
    listGone();
  } else if (status === 0) {
    toast("There is no connection, so the row was not deleted.", NOTICE_MS);
  } else {
    toast(body.error ?? "Something went wrong, so the row was not deleted.", NOTICE_MS);
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
 * Reads a rendered row into the state and makes its cells editable.
 * @param {HTMLTableRowElement} tr
 * @param {Row["phase"]} [phase]
 * @returns {Row}
 */
function adoptRow(tr, phase = "live") {
  const row = /** @type {Row} */ ({ id: tr.dataset.row ?? "", tr, cells: {}, phase, pendingDelete: false });
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
    const target = /** @type {Element} */ (event.target);
    const del = target instanceof Element ? target.closest(".del") : null;
    if (del) {
      const row = state.rows.get(/** @type {HTMLElement} */ (del.closest("tr[data-row]"))?.dataset.row ?? "");
      if (row) deleteRow(row);
      return;
    }
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
    if (row.pendingDelete) continue;
    for (const field of FIELDS) if (isDirty(row.cells[field])) cells.push(row.cells[field]);
  }
  return cells;
}

if (main) {
  const tbody = main.querySelector("tbody");
  if (tbody) {
    for (const tr of tbody.querySelectorAll("tr[data-row]")) adoptRow(/** @type {HTMLTableRowElement} */ (tr));
    wireTable(tbody);
    const template = /** @type {HTMLTemplateElement | null} */ (main.querySelector("template#blank-row"));
    const add = main.querySelector(".add-row .add");
    if (template && add) add.addEventListener("click", () => addBlankRow(tbody, template));
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
