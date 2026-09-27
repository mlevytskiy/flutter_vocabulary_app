// @ts-check
/**
 * The shared page's browser script (ADR-0002). The Worker imports this file as
 * text (wrangler.jsonc `rules`) and serves it at /assets/page-<hash>.js; the
 * table is fully rendered without it. Plain JavaScript with JSDoc types, checked
 * by `npm run typecheck` (tsconfig.client.json). Text reaches the page only
 * through `textContent`, never `innerHTML` (AC-33).
 */

document.documentElement.classList.add("js");
