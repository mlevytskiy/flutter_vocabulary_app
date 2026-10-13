// Owner feedback after the live test (2026-10-07): the story is a Ukrainian "story path" and the
// picture is ONE illustration of small connected panels, each with a caption banner carrying its
// sentence. The captions must reach the image model verbatim, so the final image prompt is built
// in code (buildPicturePrompt) from the story's captions plus a character and scenes the
// picture prompt writer AI returns as JSON (AC-08, AC-09).
import assert from "node:assert/strict";
import { test } from "node:test";
import {
  buildPicturePrompt,
  parsePictureScenes,
  picturePromptWriterPrompt,
  splitCaptions,
  storyWriterPrompt,
} from "../src/story/prompts.ts";

export const OWNER_CHARACTER = "a young adult with short dark hair, a blue jacket, and a backpack";
export const OWNER_CAPTIONS = [
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
export const OWNER_SCENES = [
  "the hero faces a giant, cute-but-intimidating monster",
  "the hero climbs a steep wall toward a high bar",
  "the hero clings to the wall with octopus-like tentacle arms",
  "a glowing compass points forward, and the hero looks fiercely determined",
  "the hero pulls out a folding emergency ladder",
  "a funny character pecks at a keyboard with a single finger",
  "a screen with a word underlined in red squiggles",
  "the startled typer swerves off the road on a scooter, with motion lines",
  "a recruiter surrounded by big speech bubbles full of tiny words",
  "the hero proudly shows a packed suitcase",
];

// The owner's exact prompt (their message of 2026-10-07), verbatim.
export const OWNER_PROMPT =
  'Create ONE single illustration in anime / manga style: a wide, horizontal "story path" made of 10 small panels that connect into one continuous scene. Arrange the panels in a snake-like route (2 rows of 5), linked by arrows and a shared background, so they read as one big picture. Use the same main character in every panel: a young adult with short dark hair, a blue jacket, and a backpack. Use a vibrant color palette and clean line art. Each panel has a caption banner at the bottom. The caption is a full sentence in Ukrainian, with one English word or phrase in the middle of it, highlighted in bold or a different color. Copy the captions exactly as written below. Spell the text correctly. Do NOT use Russian anywhere. Panels and captions, in order: «Ви tackle величезну проблему-монстра»: the hero faces a giant, cute-but-intimidating monster. «дертеся вгору, щоб live up to планки очікувань»: the hero climbs a steep wall toward a high bar. «чіпляєтесь за неї, як tenacious восьминіг»: the hero clings to the wall with octopus-like tentacle arms. «ваш determined компас усе одно показує вперед»: a glowing compass points forward, and the hero looks fiercely determined. «in a pinch ви використовуєте запасну драбину»: the hero pulls out a folding emergency ladder. «нагорі сидить one-finger typer і одним пальцем стукає по клавіатурі»: a funny character pecks at a keyboard with a single finger. «spell check підкреслює його помилку червоним»: a screen with a word underlined in red squiggles. «він лякається і veers off з дороги»: the startled typer swerves off the road on a scooter, with motion lines. «зустрічає дуже chatty рекрутера»: a recruiter surrounded by big speech bubbles full of tiny words. «і повідомляє йому, що willing to relocate, показуючи вже зібрану валізу»: the hero proudly shows a packed suitcase. Style: soft cel shading, expressive faces, dynamic angles, consistent character design, thin white borders between panels, and a cohesive background (sky gradient and clouds) that unifies all panels. Aspect ratio 16:9, high detail, legible text.';

test("the owner's 10 captions, character and scenes build EXACTLY the owner's prompt", () => {
  const prompt = buildPicturePrompt({ character: OWNER_CHARACTER, captions: OWNER_CAPTIONS, scenes: OWNER_SCENES });
  assert.equal(prompt, OWNER_PROMPT);
});

test("the story splits on the arrow into trimmed, non-empty captions", () => {
  assert.deepEqual(splitCaptions(" a b → c d  →\n→ e f "), ["a b", "c d", "e f"]);
  assert.deepEqual(splitCaptions(OWNER_CAPTIONS.join(" → ")), OWNER_CAPTIONS);
});

test("the route fits rows of at most 5 panels (7 panels: 2 rows of 4 and 3)", () => {
  const seven = buildPicturePrompt({
    character: "a girl with a red scarf",
    captions: OWNER_CAPTIONS.slice(0, 7),
    scenes: OWNER_SCENES.slice(0, 7),
  });
  assert.match(seven, /made of 7 small panels/);
  assert.match(seven, /snake-like route \(2 rows of 4 and 3\)/);
  assert.match(seven, /main character in every panel: a girl with a red scarf\./);
  assert.ok(seven.includes("«spell check підкреслює його помилку червоним»: a screen with a word underlined in red squiggles. Style:"));
  const nineteen = buildPicturePrompt({
    character: "x",
    captions: Array.from({ length: 19 }, (_, i) => `c${i}`),
    scenes: Array.from({ length: 19 }, (_, i) => `s${i}`),
  });
  assert.match(nineteen, /\(4 rows of 5, 5, 5 and 4\)/);
  const five = buildPicturePrompt({ character: "x", captions: ["a", "b", "c", "d", "e"], scenes: ["1", "2", "3", "4", "5"] });
  assert.match(five, /\(1 row of 5\)/);
});

test("the writer asks for strict JSON with one scene per numbered caption", () => {
  const { system, user } = picturePromptWriterPrompt(["Ви tackle проблему", "ви live up до очікувань"]);
  assert.match(system, /JSON/);
  assert.match(system, /"character"/);
  assert.match(system, /"scenes"/);
  assert.doesNotMatch(system, /Do not ask for any text/i);
  assert.ok(user.startsWith("Captions:\n1. Ви tackle проблему\n2. ви live up до очікувань"));
});

test("the scenes reply is validated: same count, non-empty strings, code fences tolerated", () => {
  const good = JSON.stringify({ character: " a hero ", scenes: ["one", "two"] });
  assert.deepEqual(parsePictureScenes(good, 2), { character: "a hero", scenes: ["one", "two"] });
  assert.deepEqual(parsePictureScenes("```json\n" + good + "\n```", 2), { character: "a hero", scenes: ["one", "two"] });
  assert.equal(parsePictureScenes(good, 3), null, "too few scenes");
  assert.equal(parsePictureScenes(JSON.stringify({ character: "a", scenes: ["one", " "] }), 2), null, "blank scene");
  assert.equal(parsePictureScenes(JSON.stringify({ character: "", scenes: ["one", "two"] }), 2), null, "no character");
  assert.equal(parsePictureScenes(JSON.stringify({ character: "a", scenes: ["one", 2] }), 2), null, "not strings");
  assert.equal(parsePictureScenes("A hero climbs a wall.", 2), null, "prose");
});

test("the story writer shows the owner's Ukrainian path and never Russian", () => {
  const { system } = storyWriterPrompt(["tackle"]);
  assert.ok(system.includes(OWNER_CAPTIONS.join(" → ")), "the sample is the owner's captions joined by an arrow");
  assert.match(system, /never use Russian/i);
  assert.match(system, /picturable/i);
  assert.match(system, /same main character/i);
  assert.doesNotMatch(system, /Вы |огромную|карабкаетесь|осьминог/, "no Russian text in the prompt");
  assert.doesNotMatch(system, /Russian here/);
});
