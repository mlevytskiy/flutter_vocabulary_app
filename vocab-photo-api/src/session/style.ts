/**
 * The shared page's CSS, inlined in <style> and allowed by its sha256 in the
 * Content-Security-Policy (src/session/assets.ts), so first render needs no
 * second request (spec §6).
 *
 * Two layouts on one DOM, switched by the media query alone (AC-36): wide --
 * the table beside a sticky photo area; phone -- the table scrolls both ways
 * inside `.table-scroll`, which fills the screen's leftover height, so the
 * page itself never scrolls, sideways (AC-03) or down.
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
  /* The title row; its short meta line ("24 words · until 28.10.2026") is the phone's. */
  .title { display: flex; flex-wrap: wrap; align-items: baseline; column-gap: 12px; }
  .meta-short { display: none; color: #666; font-size: 0.85rem; }
  .meta { color: #666; font-size: 0.9rem; margin: 0 0 16px; }
  .actions { display: flex; align-items: center; gap: 16px; margin: 0 0 16px; }
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
  .no-translation td.c-translation > *, .no-definition td.c-definition > * { display: none; }

  /* The lightning (US-08, US-09): the app's purple bolt, in an empty cell and beside the header. */
  .bolt { display: none; }
  .js .bolt { display: inline-flex; align-items: center; justify-content: center; width: 24px; height: 24px;
              padding: 0; border: 0; border-radius: 4px; background: none; color: #7e57c2; cursor: pointer;
              vertical-align: middle; }
  .js td .bolt { float: right; margin: -2px -4px 0 4px; }
  .bolt svg { width: 18px; height: 18px; fill: currentColor; }
  .bolt:hover, .bolt:focus-visible { background: #efe7fb; }
  td.filled .bolt, .read-only .bolt { display: none; }
  .working > .bolt, th.working .bolt { animation: working 0.9s ease-in-out infinite alternate; cursor: progress; }
  @keyframes working { from { opacity: 1; } to { opacity: 0.25; } }
  @media (prefers-reduced-motion: reduce) { .working > .bolt, th.working .bolt { animation: none; opacity: 0.5; } }
  td[data-state="notice"] .cell-note { color: #666; }

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
            gap: 8px; max-width: min(28rem, calc(100vw - 24px)); }
  .toast { display: flex; align-items: center; gap: 12px; margin: 0; padding: 10px 12px; border-radius: 6px;
           background: #1b1b1b; color: #fff; font-size: 0.9rem; box-shadow: 0 2px 8px rgba(0, 0, 0, 0.3); }
  .toast-body { min-width: 0; }
  .toast-body.one-line { max-width: 20rem; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
  .toast-word { font-weight: 600; }
  .toast-definition { opacity: 0.8; }
  .toast button { flex: none; }
  .toast button { font: inherit; font-weight: 600; padding: 4px 8px; border: 0; border-radius: 4px;
                  background: none; color: #8ab4f8; cursor: pointer; }
  .banner { margin: 0 0 16px; padding: 10px 12px; border-radius: 6px; background: #fdecea; color: #b3261e; }

  .photos figure { margin: 0; }
  .pager-track { display: flex; overflow-x: auto; scroll-snap-type: x mandatory; scrollbar-width: none; }
  .pager-track::-webkit-scrollbar { display: none; }
  .pager-track:focus-visible { outline: 2px solid #2962ff; outline-offset: 2px; border-radius: 6px; }
  .slide { flex: 0 0 100%; scroll-snap-align: start; }
  .slide img { display: block; width: 100%; height: auto; max-height: calc(100vh - 136px);
               object-fit: contain; border-radius: 6px; border: 1px solid #ddd; }
  /* The pager's arrows (AC-05), under the photo, either side of its "N of M". */
  .pager-nav:not([hidden]) { display: flex; justify-content: center; gap: 16px; margin: 6px 0 0; }
  .pager-nav button, .dialog-bar button { font: inherit; font-size: 1.4rem; line-height: 1; width: 40px; height: 40px;
                                          padding: 0; border: 1px solid #ccc; border-radius: 50%; background: #fff;
                                          color: #1b1b1b; cursor: pointer; }
  .pager-nav button:disabled, .dialog-bar button:disabled { opacity: 0.35; cursor: default; }
  .placeholder { aspect-ratio: 3 / 4; border: 1px dashed #bbb; border-radius: 6px; display: flex;
                 align-items: center; justify-content: center; color: #888; font-size: 0.85rem; }
  .slide figcaption { text-align: center; color: #666; font-size: 0.85rem; margin: 4px 0 0; }
  /* The phone's photo button, beside the download link. */
  .photo-button { display: none; position: relative; flex: none; width: 44px; height: 44px;
                  padding: 0; border: 0; background: none; cursor: pointer; }
  .thumb { position: absolute; inset: 0; width: 100%; height: 100%; object-fit: cover; background: #ccc;
           border: 2px solid #fff; border-radius: 8px; box-shadow: 0 1px 4px rgba(0, 0, 0, 0.35); }
  .photo-button.stack .thumb:nth-child(1) { transform: rotate(-7deg); }
  .photo-button.stack .thumb:nth-child(2) { transform: rotate(5deg); }

  /* The phone's photo dialog (AC-07): full screen, a strip of photos moved by
     the script's swipe, each photo zoomed by pinch or a double tap. */
  .photo-dialog { width: 100vw; max-width: none; height: 100vh; height: 100dvh; max-height: none; margin: 0;
                  padding: 0; border: 0; background: #000; color: #fff; overflow: hidden; }
  .photo-dialog[open] { display: flex; flex-direction: column; }
  .photo-dialog::backdrop { background: #000; }
  .dialog-bar { flex: none; display: flex; align-items: center; gap: 8px; padding: 8px 12px; }
  .dialog-count { flex: 1; text-align: center; font-size: 0.9rem; }
  .dialog-bar button { border-color: #555; background: #1b1b1b; color: #fff; }
  .dialog-bar [data-dialog="close"] { margin-left: 8px; }
  .dialog-view { flex: 1; min-height: 0; overflow: hidden; touch-action: none; }
  .dialog-strip { display: flex; height: 100%; transition: transform 0.25s ease-out; }
  .dialog-strip.dragging { transition: none; }
  .dialog-slide { flex: 0 0 100%; height: 100%; margin: 0; overflow: hidden; display: flex;
                  align-items: center; justify-content: center; }
  .dialog-slide img { display: block; max-width: 100%; max-height: 100%; object-fit: contain;
                      transform-origin: 0 0; user-select: none; -webkit-user-drag: none; }
  .dialog-slide .placeholder { width: min(80%, 20rem); color: #aaa; border-color: #555; }
  html.dialog-open, html.dialog-open body { overflow: hidden; }
  @media (prefers-reduced-motion: reduce) { .dialog-strip { transition: none; } }

  @media (min-width: 900px) {
    table { max-width: 100%; }
    .has-photos .layout { display: grid; grid-template-columns: minmax(0, 1fr) var(--w-photos);
                  gap: 24px; align-items: start; }
    .photos { position: sticky; top: 16px; }
    /* The next photo peeks in at the side, so there is visibly more than one. */
    .pager-track { gap: 12px; }
    .slide { flex-basis: 88%; }
    .slide:only-child { flex-basis: 100%; }
    /* A recognised row of the photo on display (AC-05, AC-34). Wide layout
       only: there is no row highlighting on a phone (spec §3). A cell's own
       not-saved state still shows over it. */
    tr.from-photo td { background: #e8f0fe; }
    tr.from-photo td:first-child { box-shadow: inset 3px 0 #2962ff; }
    tr.from-photo td[data-state="unsaved"], tr.from-photo td[data-state="conflict"] { background: #fff1f0; }
  }
  @media (max-width: 899.98px) {
    :root { --w-word: 6.5rem; --w-translation: 6.5rem; --w-definition: min(18rem, 75vw); }
    /* One scroll on a phone: the page is exactly one screen tall, so the title
       and the actions sit above the table and "+ Add a word" and the credit
       stay visible below it. The table box takes what height is left and
       scrolls inside itself; a short table keeps its own height. Everything
       else keeps its content height (a flex item's min-height is auto). */
    main { padding: 12px; display: flex; flex-direction: column; height: 100vh; height: 100dvh; }
    .layout, .table-area { flex: 1 1 auto; min-height: 0; display: flex; flex-direction: column; }
    .table-scroll { flex: 0 1 auto; min-height: 0; overflow: auto; border-radius: 6px; }
    table { width: max-content; }
    .photos { display: none; }
    /* At the right edge of the actions row, clear of the rotated stack's corners. */
    .js .photo-button { display: block; margin: 0 8px 0 auto; }
    /* One line: the short meta sits right after "Vocabulary" and never wraps. */
    .title { margin: 0 0 12px; flex-wrap: nowrap; column-gap: 6px; }
    .title h1 { flex: none; }
    .meta-short { white-space: nowrap; }
    .title h1 { margin: 0; }
    .meta-short { display: inline; }
    .meta { display: none; }
  }

  @media (prefers-color-scheme: dark) {
    body { background: #121212; color: #ececec; }
    table { background: #1c1c1c; border-color: #333; }
    th { background: #262626; }
    th, td { border-color: #2e2e2e; }
    .meta, .meta-short, .n, .credit, .slide figcaption, .placeholder { color: #9a9a9a; }
    .slide img, .placeholder { border-color: #333; }
    .thumb { border-color: #1c1c1c; background: #333; }
    .needs-word-mark { color: #e0a040; }
    td[data-state="unsaved"], td[data-state="conflict"] { background: #3a1d1b; }
    td[data-state="saved"] .cell-note { color: #81c995; }
    td[data-state="unsaved"] .cell-note, td[data-state="conflict"] .cell-note { color: #f28b82; }
    .cell-note q { color: #ececec; }
    td[data-state="notice"] .cell-note { color: #9a9a9a; }
    .js .bolt { color: #b39ddb; }
    .bolt:hover, .bolt:focus-visible { background: #2e2540; }
    .cell-note button { background: #262626; color: #ececec; border-color: #555; }
    .banner { background: #3a1d1b; color: #f28b82; }
    .del:hover, .del:focus-visible { background: #3a1d1b; }
    .add { color: #8ab4f8; border-color: #8ab4f8; }
    .toast { background: #ececec; color: #1b1b1b; }
    .toast button { color: #1a56d6; }
    @keyframes changed { from { background: #4a3f10; } to { background: transparent; } }
    .gone { color: #ccc; }
    .pager-nav button { background: #262626; color: #ececec; border-color: #555; }
  }
  @media (prefers-color-scheme: dark) and (min-width: 900px) {
    tr.from-photo td { background: #1c2a44; }
    tr.from-photo td:first-child { box-shadow: inset 3px 0 #8ab4f8; }
    tr.from-photo td[data-state="unsaved"], tr.from-photo td[data-state="conflict"] { background: #3a1d1b; }
  }
`;
