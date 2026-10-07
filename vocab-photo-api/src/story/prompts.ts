// The prompts of a story run's two text steps: the story writer and the picture prompt
// writer (spec AC-08, sad §4). Pure, so they run anywhere.

/** The owner's sample story (their live-test feedback, 2026-10-07): the format the story writer is shown. */
const SAMPLE_CAPTIONS = [
  "Ви tackle величезну проблему-монстра",
  "дертеся вгору, щоб live up to планки очікувань",
  "чіпляєтесь за неї, як tenacious восьминіг",
  "ваш determined компас усе одно показує вперед",
  "in a pinch ви використовуєте запасну драбину",
  "нагорі сидить one-finger typer і одним пальцем стукає по клавіатурі",
  "spell check підкреслює його помилку червоним",
  "він лякається і veers off з дороги",
  "зустрічає дуже chatty рекрутера",
  "і повідомляє йому, що willing to relocate, показуючи вже зібрану валізу",
];
const SAMPLE_STORY = SAMPLE_CAPTIONS.join(" → ");

export interface Prompt {
  system: string;
  user: string;
}

/** The story writer: one connected, vivid story over the group's words. */
export function storyWriterPrompt(words: readonly string[]): Prompt {
  return {
    system: [
      "You write mnemonic stories that help a Ukrainian speaker remember English words.",
      "Write one short, vivid, connected story in Ukrainian as a chain of sentences joined by \"→\".",
      "Use exactly one sentence for each English word, in any order that makes the story flow.",
      "Put each English word into its sentence exactly as it is given, in English, in the middle of the Ukrainian text.",
      "Do not translate the English word, change its ending or split a phrase. A phrase stays whole and in order.",
      "Make the images concrete, funny or surprising so they are easy to picture and remember.",
      "Each sentence must be a concrete, picturable scene that continues the journey of the same main character.",
      "Always write in Ukrainian and never use Russian.",
      "Reply with the story only: no title, no list, no explanation.",
      "",
      "Example of the format (the English words stay in English inside Ukrainian sentences):",
      SAMPLE_STORY,
    ].join("\n"),
    user: `Words to use, one per sentence:\n${words.map((word) => `- ${word}`).join("\n")}`,
  };
}

/** The captions of a story: its sentences between the arrows, trimmed, without empty ones. */
export function splitCaptions(story: string): string[] {
  return story
    .split("→")
    .map((caption) => caption.trim())
    .filter((caption) => caption.length > 0);
}

/**
 * The picture prompt writer: asked only for one consistent main character and one short scene per
 * caption, as strict JSON. The captions themselves never pass through it (see `buildPicturePrompt`).
 */
export function picturePromptWriterPrompt(captions: readonly string[]): Prompt {
  return {
    system: [
      "You write input for an AI image generator that draws one illustration made of several small connected panels,",
      "one panel per caption of a mnemonic story. Do not write the captions or any text for the picture.",
      "Describe, in English: one main character who appears in every panel (hair, clothes, accessories),",
      "and for each caption one short scene: what the panel shows, concretely and picturably.",
      'Reply with strict JSON only, no code fence, no comment: {"character": "<one consistent main character description>", "scenes": ["<short scene for caption 1>", "<short scene for caption 2>", ...]}.',
      `"scenes" must have exactly one string per caption, in the same order (${captions.length} in this story).`,
    ].join("\n"),
    user: `Captions:\n${captions.map((caption, i) => `${i + 1}. ${caption}`).join("\n")}`,
  };
}

export interface PictureScenes {
  character: string;
  scenes: string[];
}

/** Reads the picture prompt writer's reply: strict JSON (a code fence is tolerated) with one scene per caption, or null. */
export function parsePictureScenes(reply: string, captionCount: number): PictureScenes | null {
  const unfenced = reply.trim().replace(/^```[a-zA-Z]*\s*/, "").replace(/\s*```$/, "").trim();
  let data: unknown;
  try {
    data = JSON.parse(unfenced);
  } catch {
    return null;
  }
  if (typeof data !== "object" || data === null) return null;
  const { character, scenes } = data as { character?: unknown; scenes?: unknown };
  if (typeof character !== "string" || character.trim() === "") return null;
  if (!Array.isArray(scenes) || scenes.length !== captionCount) return null;
  if (!scenes.every((scene) => typeof scene === "string" && scene.trim() !== "")) return null;
  return { character: character.trim(), scenes: scenes.map((scene: string) => scene.trim()) };
}

/** How many panels go in each row of the snake-like route: rows of at most 5, the first rows one longer when uneven. */
function rowSizes(count: number): number[] {
  const rows = Math.max(1, Math.ceil(count / 5));
  const base = Math.floor(count / rows);
  const extra = count % rows;
  return Array.from({ length: rows }, (_, i) => base + (i < extra ? 1 : 0));
}

function describeRows(count: number): string {
  const sizes = rowSizes(count);
  const rows = sizes.length === 1 ? "1 row" : `${sizes.length} rows`;
  if (sizes.every((size) => size === sizes[0])) return `${rows} of ${sizes[0]}`;
  return `${rows} of ${sizes.slice(0, -1).join(", ")} and ${sizes[sizes.length - 1]}`;
}

const endWithStop = (text: string) => (/[.!?]$/.test(text) ? text : `${text}.`);

/**
 * The final image prompt, assembled in code so the captions reach the image model verbatim:
 * one illustration of small connected panels, each with a caption banner (owner feedback, 2026-10-07).
 */
export function buildPicturePrompt(input: { character: string; captions: readonly string[]; scenes: readonly string[] }): string {
  const count = input.captions.length;
  const panels = input.captions.map((caption, i) => `«${caption}»: ${endWithStop(input.scenes[i])}`).join(" ");
  return [
    `Create ONE single illustration in anime / manga style: a wide, horizontal "story path" made of ${count} small ${count === 1 ? "panel" : "panels"} that connect into one continuous scene.`,
    `Arrange the panels in a snake-like route (${describeRows(count)}), linked by arrows and a shared background, so they read as one big picture.`,
    `Use the same main character in every panel: ${input.character.trim().replace(/\.$/, "")}.`,
    "Use a vibrant color palette and clean line art.",
    "Each panel has a caption banner at the bottom.",
    "The caption is a full sentence in Ukrainian, with one English word or phrase in the middle of it, highlighted in bold or a different color.",
    "Copy the captions exactly as written below. Spell the text correctly. Do NOT use Russian anywhere.",
    `Panels and captions, in order: ${panels}`,
    "Style: soft cel shading, expressive faces, dynamic angles, consistent character design, thin white borders between panels, and a cohesive background (sky gradient and clouds) that unifies all panels.",
    "Aspect ratio 16:9, high detail, legible text.",
  ].join(" ");
}
