/**
 * The shared page's CSS, inlined in <style> and allowed by its sha256 in the
 * Content-Security-Policy (src/session/assets.ts), so first render needs no
 * second request (spec §6).
 *
 * Two layouts on one DOM, switched by the media query alone (AC-36): wide --
 * the table beside a sticky photo area; phone -- the table scrolls both ways
 * inside `.table-scroll` and the page never scrolls sideways (AC-03).
 *
 * Provisional values (spec OQ-5, for the owner to confirm): the breakpoint is
 * 900px (a media query cannot read a custom property, so it is written out
 * twice below); the column max widths are the custom properties in :root and
 * in each layout's block. A cell's text sits in `.v`, whose max-width caps the
 * column; longer text wraps and the row grows taller (AC-02, AC-04).
 */
export const STYLE = `
  :root { color-scheme: light dark;
          --w-word: 10rem; --w-translation: 10rem; --w-definition: 36rem;
          --w-photos: clamp(16rem, 28vw, 24rem); }
  * { box-sizing: border-box; }
  body { margin: 0; font: 16px/1.45 -apple-system, "Segoe UI", Roboto, sans-serif;
         background: #fafafa; color: #1b1b1b; }
  main { max-width: 1440px; margin: 0 auto; padding: 16px; }
  h1 { font-size: 1.4rem; margin: 0 0 4px; }
  .meta { color: #666; font-size: 0.9rem; margin: 0 0 16px; }
  .actions { margin: 0 0 16px; }
  .btn { display: inline-block; padding: 10px 16px; border-radius: 6px; background: #2962ff;
         color: #fff; font-weight: 600; text-decoration: none; }
  .btn:active { background: #1e4fd6; }
  .gone { text-align: center; padding: 48px 0; color: #444; }
  .credit { color: #666; font-size: 0.8rem; margin: 8px 0 0; }
  .no-definition .credit { display: none; }

  .layout, .table-area, .table-scroll { min-width: 0; }
  table { border-collapse: separate; border-spacing: 0; background: #fff;
          border: 1px solid #ddd; border-radius: 6px; counter-reset: row; }
  th, td { padding: 10px 8px; text-align: left; vertical-align: top;
           border-bottom: 1px solid #e6e6e6; }
  th { background: #eee; font-weight: 600; font-size: 0.9rem;
       position: sticky; top: 0; z-index: 1; }
  th:first-child { border-top-left-radius: 6px; }
  th:last-child { border-top-right-radius: 6px; }
  tbody tr:last-child td { border-bottom: 0; }
  tbody tr { counter-increment: row; }
  .n { width: 1px; white-space: nowrap; text-align: right; color: #888; padding-right: 4px; }
  td.n::before { content: counter(row); }
  .v { white-space: pre-wrap; overflow-wrap: anywhere; min-height: 1.45em; }
  .c-word .v { max-width: var(--w-word); }
  .c-translation .v { max-width: var(--w-translation); }
  .c-definition .v { max-width: var(--w-definition); }
  .needs-word-mark { display: none; margin: 2px 0 0; font-size: 0.8rem; font-style: italic;
                     color: #a15c00; max-width: var(--w-word); }
  tr.needs-word .needs-word-mark { display: block; }
  .add-col { font: inherit; font-size: 0.85rem; font-weight: 600; padding: 2px 6px; white-space: nowrap;
             border: 1px dashed #999; border-radius: 4px; background: none; color: inherit; cursor: pointer; }
  .no-translation td.c-translation .v, .no-definition td.c-definition .v { display: none; }

  .v:focus { outline: 2px solid #2962ff; outline-offset: 3px; border-radius: 2px; }
  td[data-state="saving"] .v { opacity: 0.6; }
  td[data-state="unsaved"], td[data-state="conflict"] { background: #fff1f0; box-shadow: inset 3px 0 #d93025; }
  .cell-note { font-size: 0.8rem; margin: 4px 0 0; max-width: max(var(--w-word), 12rem); }
  .cell-note:empty { display: none; }
  td[data-state="saved"] .cell-note { color: #1e7d32; }
  td[data-state="unsaved"] .cell-note, td[data-state="conflict"] .cell-note { color: #b3261e; }
  .cell-note p { margin: 0; }
  .cell-note q { display: block; margin: 2px 0 4px; white-space: pre-wrap; overflow-wrap: anywhere; color: #1b1b1b; }
  .cell-note button { font: inherit; margin: 0 6px 0 0; padding: 4px 8px; border-radius: 4px;
                      border: 1px solid #999; background: #fff; color: #1b1b1b; cursor: pointer; }
  .del, .add-row { display: none; }
  .js .del { display: inline-block; font: inherit; font-size: 1rem; line-height: 1; margin: 0 0 0 4px;
             min-width: 24px; min-height: 24px; padding: 2px 5px; border: 0; border-radius: 4px; background: none;
             color: #999; cursor: pointer; vertical-align: middle; }
  .del:hover, .del:focus-visible { color: #b3261e; background: #fdecea; }
  .js .add-row { display: block; margin: 8px 0 0; }
  .add { font: inherit; font-weight: 600; padding: 8px 14px; border-radius: 6px; cursor: pointer;
         border: 1px dashed #2962ff; background: none; color: #2962ff; }
  tr.pending-delete { display: none; }
  tr.changed td { animation: changed 3s ease-out; }
  @keyframes changed { from { background: #fff3c4; } to { background: transparent; } }
  .toasts { position: fixed; left: 12px; bottom: 16px; z-index: 3; display: flex; flex-direction: column;
            gap: 8px; max-width: min(28rem, calc(100vw - 104px)); }
  .toast { display: flex; align-items: center; gap: 12px; margin: 0; padding: 10px 12px; border-radius: 6px;
           background: #1b1b1b; color: #fff; font-size: 0.9rem; box-shadow: 0 2px 8px rgba(0, 0, 0, 0.3); }
  .toast button { font: inherit; font-weight: 600; padding: 4px 8px; border: 0; border-radius: 4px;
                  background: none; color: #8ab4f8; cursor: pointer; }
  .banner { margin: 0 0 16px; padding: 10px 12px; border-radius: 6px; background: #fdecea; color: #b3261e; }

  .photos figure { margin: 0; }
  .pager-track { display: flex; overflow-x: auto; scroll-snap-type: x mandatory; }
  .slide { flex: 0 0 100%; scroll-snap-align: start; }
  .slide img { display: block; width: 100%; height: auto; max-height: calc(100vh - 96px);
               object-fit: contain; border-radius: 6px; border: 1px solid #ddd; }
  .placeholder { aspect-ratio: 3 / 4; border: 1px dashed #bbb; border-radius: 6px; display: flex;
                 align-items: center; justify-content: center; color: #888; font-size: 0.85rem; }
  .slide figcaption { text-align: center; color: #666; font-size: 0.85rem; margin: 4px 0 0; }
  .photo-button { display: none; position: fixed; right: 16px; bottom: 16px; z-index: 2;
                  width: 64px; height: 64px; padding: 0; border: 0; background: none; cursor: pointer; }
  .thumb { position: absolute; inset: 0; width: 100%; height: 100%; object-fit: cover; background: #ccc;
           border: 2px solid #fff; border-radius: 8px; box-shadow: 0 1px 4px rgba(0, 0, 0, 0.35); }
  .photo-button.stack .thumb:nth-child(1) { transform: rotate(-7deg); }
  .photo-button.stack .thumb:nth-child(2) { transform: rotate(5deg); }

  @media (min-width: 900px) {
    table { max-width: 100%; }
    .has-photos .layout { display: grid; grid-template-columns: minmax(0, 1fr) var(--w-photos);
                  gap: 24px; align-items: start; }
    .photos { position: sticky; top: 16px; }
  }
  @media (max-width: 899.98px) {
    :root { --w-word: 6.5rem; --w-translation: 6.5rem; --w-definition: min(18rem, 75vw); }
    main { padding: 12px; }
    .table-scroll { overflow: auto; max-height: 100vh; max-height: 100dvh; border-radius: 6px; }
    table { width: max-content; }
    .photos { display: none; }
    .js .photo-button { display: block; }
  }

  @media (prefers-color-scheme: dark) {
    body { background: #121212; color: #ececec; }
    table { background: #1c1c1c; border-color: #333; }
    th { background: #262626; }
    th, td { border-color: #2e2e2e; }
    .meta, .n, .credit, .slide figcaption, .placeholder { color: #9a9a9a; }
    .slide img, .placeholder { border-color: #333; }
    .thumb { border-color: #1c1c1c; background: #333; }
    .needs-word-mark { color: #e0a040; }
    td[data-state="unsaved"], td[data-state="conflict"] { background: #3a1d1b; }
    td[data-state="saved"] .cell-note { color: #81c995; }
    td[data-state="unsaved"] .cell-note, td[data-state="conflict"] .cell-note { color: #f28b82; }
    .cell-note q { color: #ececec; }
    .cell-note button { background: #262626; color: #ececec; border-color: #555; }
    .banner { background: #3a1d1b; color: #f28b82; }
    .del:hover, .del:focus-visible { background: #3a1d1b; }
    .add { color: #8ab4f8; border-color: #8ab4f8; }
    .toast { background: #ececec; color: #1b1b1b; }
    .toast button { color: #1a56d6; }
    @keyframes changed { from { background: #4a3f10; } to { background: transparent; } }
    .gone { color: #ccc; }
  }
`;
