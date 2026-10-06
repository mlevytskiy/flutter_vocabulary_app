// @ts-check
/**
 * The learn pages' browser script (ADR-0002). The Worker imports this file as
 * text (wrangler.jsonc `rules`) and serves it at /assets/learn-<hash>.js; both
 * pages are complete HTML without it. Plain JavaScript with JSDoc types,
 * checked by `npm run typecheck` (tsconfig.client.json).
 *
 * Learn page: every tick keeps Start's link, the hint and the address's
 * `?pick=` in step, so the browser's back button returns to an address the
 * server renders ticked (AC-05). Start does nothing while nothing is ticked
 * (AC-07). Coming-soon page: "Back to exercises" goes back in history when the
 * previous entry is this session's learn page, else follows its own link, so
 * the history never grows a loop (AC-05).
 */

function initLearnPage(/** @type {HTMLElement} */ main) {
  const session = main.dataset.session ?? "";
  const boxes = Array.from(main.querySelectorAll('input[type="checkbox"][name="pick"]')).filter(
    (el) => el instanceof HTMLInputElement
  );
  const startEl = main.querySelector("a.start");
  const hintEl = main.querySelector(".hint");
  if (!(startEl instanceof HTMLAnchorElement) || !(hintEl instanceof HTMLElement)) return;
  const start = startEl;
  const hint = hintEl;

  start.addEventListener("click", (event) => {
    if (start.getAttribute("aria-disabled") === "true") event.preventDefault();
  });

  function sync() {
    // Boxes are in plan order, so the first ticked one is the first exercise.
    const picks = boxes.filter((box) => box.checked).map((box) => box.value);
    const query = picks.map((id) => `pick=${encodeURIComponent(id)}`).join("&");
    if (picks.length === 0) {
      start.setAttribute("aria-disabled", "true");
      start.removeAttribute("href");
      hint.textContent = "Pick at least one exercise";
      hint.hidden = false;
    } else {
      start.removeAttribute("aria-disabled");
      start.setAttribute("href", `/s/${encodeURIComponent(session)}/learn/${encodeURIComponent(picks[0])}?${query}`);
      hint.textContent = "";
      hint.hidden = true;
    }
    history.replaceState(history.state, "", location.pathname + (query ? `?${query}` : "") + location.hash);
  }

  for (const box of boxes) box.addEventListener("change", sync);
  sync();
}

function initComingSoonPage(/** @type {HTMLAnchorElement} */ back) {
  back.addEventListener("click", (event) => {
    if (!document.referrer) return;
    let previous;
    try {
      previous = new URL(document.referrer);
    } catch {
      return;
    }
    if (previous.origin === location.origin && previous.pathname === new URL(back.href).pathname) {
      event.preventDefault();
      history.back();
    }
  });
}

const learnMain = document.querySelector("main.learn[data-session]");
const backLink = document.querySelector("a.back");
if (learnMain instanceof HTMLElement) initLearnPage(learnMain);
else if (backLink instanceof HTMLAnchorElement) initComingSoonPage(backLink);
