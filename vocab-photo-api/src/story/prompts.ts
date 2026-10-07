// The prompts of a story run's two text steps: the story writer and the picture prompt
// writer (spec AC-08, sad §4). Pure, so they run anywhere.

/** The owner's sample story (spec §1): the format the story writer is shown. Russian there; ours is Ukrainian. */
const SAMPLE_STORY =
  "Вы tackle огромную проблему-монстра → карабкаетесь вверх, чтобы live up to планки ожиданий → " +
  "цепляетесь за неё как tenacious осьминог → ваш determined компас всё равно показывает вперёд → " +
  "in a pinch вы используете запасную лестницу → наверху сидит one-finger typer и одним пальцем стучит по клавиатуре → " +
  "spell check подчёркивает его ошибку красным → он пугается и veers off с дороги → " +
  "встречает очень chatty рекрутера → и сообщает ему, что willing to relocate, показывая уже собранный чемодан.";

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
      "Reply with the story only: no title, no list, no explanation.",
      "",
      "Example of the format (Russian here, yours is Ukrainian):",
      SAMPLE_STORY,
    ].join("\n"),
    user: `Words to use, one per sentence:\n${words.map((word) => `- ${word}`).join("\n")}`,
  };
}

/** The picture prompt writer: one prompt for an image of the whole story. */
export function picturePromptWriterPrompt(story: string): Prompt {
  return {
    system: [
      "You write prompts for an AI image generator.",
      "Read the mnemonic story and write one prompt, in English, for a single picture that shows its scenes together,",
      "so the picture reminds the viewer of the story from start to end.",
      "Describe the characters, objects, setting and mood concretely, in a consistent illustrated style.",
      "Do not ask for any text, letters or captions in the picture.",
      "Reply with the picture prompt only.",
    ].join("\n"),
    user: `Story:\n${story}`,
  };
}
