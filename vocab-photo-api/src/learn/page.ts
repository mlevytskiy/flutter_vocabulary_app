import { escapeHtml, shell } from "../session/page";
import { EXERCISES, type Exercise } from "./exercises";

/**
 * Server-rendered learn pages (ADR-0002): the learn page, the no-words page and the
 * coming-soon page, inside the shared page's `shell()` and stylesheet. Every stored
 * value goes through `escapeHtml`. The ticks travel in the address as `pick`
 * (already filtered to available exercises by the route); `learn.js` keeps
 * Start's link and the hint in step with them once it loads.
 */

function sessionPath(sessionId: string): string {
  return `/s/${encodeURIComponent(sessionId)}`;
}

function pickQuery(picks: readonly string[]): string {
  return picks.length === 0 ? "" : `?${picks.map((id) => `pick=${encodeURIComponent(id)}`).join("&")}`;
}

function renderExercise(exercise: Exercise, ticked: boolean): string {
  const id = escapeHtml(exercise.id);
  const name = escapeHtml(exercise.name);
  if (!exercise.available) {
    return `<label class="exercise soon"><input type="checkbox" value="${id}" disabled> ${name} <span>Coming soon</span></label>`;
  }
  return `<label class="exercise"><input type="checkbox" name="pick" value="${id}"${ticked ? " checked" : ""}> ${name}</label>`;
}

/** `picks`: the valid, available exercise ids the address asked for. */
export function renderLearnPage(sessionId: string, wordCount: number, picks: readonly string[], scriptPath: string): string {
  const words = `${wordCount} ${wordCount === 1 ? "word" : "words"}`;
  const sections = ([1, 2, 3] as const)
    .map((stage) => {
      const rows = EXERCISES.filter((e) => e.stage === stage)
        .map((e) => renderExercise(e, picks.includes(e.id)))
        .join("\n");
      return `<h2>Step ${stage}</h2>\n${rows}`;
    })
    .join("\n");
  const first = EXERCISES.find((e) => picks.includes(e.id));
  const start = first
    ? `<a class="btn start" href="${escapeHtml(`${sessionPath(sessionId)}/learn/${encodeURIComponent(first.id)}${pickQuery(picks)}`)}">Start</a>`
    : `<a class="btn start" aria-disabled="true">Start</a>`;
  const hint = `<p class="hint" aria-live="polite"${first ? " hidden" : ""}>${first ? "" : "Pick at least one exercise"}</p>`;
  const body = `<main class="learn" data-session="${escapeHtml(sessionId)}">
<h1>Learn</h1>
<p class="count">${words}</p>
${sections}
<p>${start}</p>
${hint}
</main>`;
  return shell("Learn", body, scriptPath);
}

export function renderNoWordsPage(sessionId: string): string {
  return shell(
    "No words to learn",
    `<main class="learn">
<h1>No words to learn</h1>
<p><a href="${escapeHtml(sessionPath(sessionId))}">Back to the word list</a></p>
</main>`
  );
}

export function renderComingSoonPage(sessionId: string, exercise: Exercise, picks: readonly string[], scriptPath: string): string {
  const back = `${sessionPath(sessionId)}/learn${pickQuery(picks)}`;
  return shell(
    exercise.name,
    `<main class="learn">
<h1>${escapeHtml(exercise.name)}</h1>
<p>Coming soon — this exercise is not ready yet.</p>
<p><a class="btn back" href="${escapeHtml(back)}">Back to exercises</a></p>
</main>`,
    scriptPath
  );
}
