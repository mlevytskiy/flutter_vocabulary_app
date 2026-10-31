import assert from "node:assert/strict";
import { test } from "node:test";
import { freshWords, mixedInteraction, mixedPrompt, mixedTarget, readMixedTurn } from "../src/learn/talk-mixed.ts";
import { parseTalkRequest, nextTarget } from "../src/learn/talk.ts";
import { appHeaders, baseUrl } from "./helpers.mjs";

const start = { kind: 'start', mode: 'mixed', scene: 'A missing boat', words: [
  { word: 'shore', translation: 'берег' }, { word: 'tide', translation: 'приплив' },
], target: 'shore', history: [] };
const request = (n) => ({ ...start, kind: n ? 'reply' : 'start', history: Array.from({ length: n }, () => ({ role: 'learner', text: 'Help me' })) });

test('three rounds of two choices and one speaking task then a concrete ending', () => {
  assert.deepEqual(Array.from({ length: 10 }, (_, n) => mixedInteraction(request(n))),
    ['choice', 'choice', 'speak', 'choice', 'choice', 'speak', 'choice', 'choice', 'speak', 'complete']);
});

test('choice attribution survives parsing and cannot advance the vocabulary target', () => {
  const req = { ...request(1), history: [{ role: 'learner', text: 'Explore the shore', source: 'choice' }] };
  assert.deepEqual(parseTalkRequest(req), req);
  assert.equal(nextTarget(req), 'shore');
  assert.equal(nextTarget({ ...req, history: [{ role: 'learner', text: 'Explore the shore' }] }), 'tide');
  assert.ok(parseTalkRequest({ ...req, history: [{ role: 'ai', text: 'Hello', source: 'choice' }] }).error);
});

test('structured output refuses unusable choices and speech tasks, and never trusts a model mode', () => {
  const answer = { opening: 'What will you do?', choices: ['Ask for help', 'Search alone'] };
  assert.equal(readMixedTurn(JSON.stringify(answer), start).interaction, 'choice');
  for (const choices of [[], ['Only one'], ['A', 'a'], ['A', 2], ['A', 'x'.repeat(81)]]) {
    assert.equal(readMixedTurn(JSON.stringify({ ...answer, choices }), start), null);
  }
  assert.equal(readMixedTurn('not json', start), null);
  assert.equal(readMixedTurn(JSON.stringify({ reply: 'Where?', choices: ['A', 'B'] }), request(2)), null);
  assert.equal(readMixedTurn(JSON.stringify({ reply: 'Where?', interaction: 'choice', speakingPrompt: 'Describe the location.' }), request(2)).interaction, 'speak');
  assert.equal(readMixedTurn(JSON.stringify({ reply: 'You found the boat!' }), request(9)).interaction, 'complete');
  assert.match(mixedPrompt(request(9), { system: '', user: '' }).system, /Do not introduce another problem/);
});

test('mixed route returns choices, a speaking task, and an ending through the AI contract', async () => {
  const post = async (req) => {
    const response = await fetch(`${baseUrl}/learn/talk`, { method: 'POST', headers: appHeaders({ 'content-type': 'application/json' }), body: JSON.stringify(req) });
    assert.equal(response.status, 200);
    return response.json();
  };
  const opening = await post(start);
  assert.equal(opening.interaction, 'choice');
  assert.equal(opening.choices.length, 2);
  assert.ok(opening.mission);
  const speech = await post(request(2));
  assert.equal(speech.interaction, 'speak');
  assert.ok(speech.speakingPrompt);
  assert.deepEqual(speech.choices, []);
  const end = await post(request(9));
  assert.equal(end.interaction, 'complete');
  assert.match(end.reply, /found your boat/);
});

test("owner 2026-10-24: the mixed prompt makes the AI use the practice words and aim speaking tasks at the target", async () => {
  const { mixedPrompt } = await import("../src/learn/talk-mixed.ts");
  const words = [{ word: "shore", translation: "берег" }, { word: "tide", translation: "приплив" }];
  const turn = (n) => Array.from({ length: n * 2 }, (_, i) => ({ role: i % 2 ? "learner" : "ai", text: `line ${i}` }));
  const choice = mixedPrompt({ kind: "reply", scene: "S", words, target: "tide", history: turn(1), mode: "mixed" }, { system: "", user: "" });
  assert.match(choice.system, /uses 2 practice words/);
  assert.match(choice.system, /at least two of the choices contain a practice word/);
  const speak = mixedPrompt({ kind: "reply", scene: "S", words, target: "tide", history: turn(2), mode: "mixed" }, { system: "", user: "" });
  assert.match(speak.system, /natural answer needs the target word/);
  const start = mixedPrompt({ kind: "start", scene: "S", words, target: "tide", history: [], mode: "mixed" }, { system: "pick 4-6 x, without any of the picked words", user: "" });
  assert.match(start.system, /using one of the picked words naturally/);
  assert.doesNotMatch(start.system, /without any of the picked words/);
});

test("owner 2026-10-24: a mixed target moves every turn to a word the learner has not said; fresh words are the ones no line used", () => {
  const words = ["shore", "tide", "fog", "gale"].map((word) => ({ word, translation: "t" }));
  const base = { kind: "reply", scene: "S", words, target: "shore", mode: "mixed" };
  const h = (...lines) => lines.map(([role, text, source]) => ({ role, text, ...(source ? { source } : {}) }));
  assert.equal(mixedTarget({ ...base, history: h(["ai", "Hi"], ["learner", "Hello"]) }), "tide", "moves on even without the word");
  assert.equal(mixedTarget({ ...base, history: h(["ai", "Hi"], ["learner", "The tide is high"]) }), "fog", "skips a word the learner said");
  assert.equal(mixedTarget({ ...base, history: h(["ai", "Hi"], ["learner", "Watch the tide", "choice"]) }), "tide", "a picked choice is not said");
  assert.equal(mixedTarget({ ...base, kind: "start", history: [] }), "shore");
  assert.deepEqual(freshWords({ ...base, history: h(["ai", "The fog came"], ["learner", "Near the shore"]) }), ["tide", "gale"]);
  const { user } = mixedPrompt({ ...base, history: h(["ai", "The fog came"], ["learner", "ok"]) }, { system: "", user: "" });
  assert.deepEqual(JSON.parse(user).fresh, ["shore", "tide", "gale"]);
});

// ---- learn-warm-up-v2 T5: a grammar focus on every turn and a verdict per reply (AC-09, AC-10, ADR-0005) ----

const grammarWords = [{ word: "shore", translation: "берег" }, { word: "tide", translation: "приплив" }];
const plainStart = { kind: "start", scene: "Lost boat", words: grammarWords, target: "shore", history: [] };
const plainReply = (text, extra = {}) => ({
  kind: "reply", scene: "Brief", words: grammarWords, target: "shore",
  history: [{ role: "ai", text: "What happened?" }, { role: "learner", text, ...extra }],
});

test("AC-09: grammar of 1 to 40 characters is taken, trimmed, on the start and on every reply; none leaves the request as before", async () => {
  const { parseTalkRequest } = await import("../src/learn/talk.ts");
  assert.equal(parseTalkRequest({ ...plainStart, grammar: "  Present Perfect " }).grammar, "Present Perfect");
  assert.equal(parseTalkRequest({ ...plainReply("I lost it"), grammar: "x".repeat(40) }).grammar, "x".repeat(40));
  assert.equal(parseTalkRequest({ ...plainReply("I lost it"), mode: "mixed", grammar: "Past Simple" }).grammar, "Past Simple");
  for (const grammar of ["", "   ", "x".repeat(41), 3, null, ["Past Simple"]]) {
    assert.equal(typeof parseTalkRequest({ ...plainReply("I lost it"), grammar }).error, "string", JSON.stringify(grammar));
  }
  assert.deepEqual(Object.keys(parseTalkRequest(plainStart)), ["kind", "scene", "words", "target", "history"]);
});

test("AC-09: without a rule every prompt stays exactly as it was", async () => {
  const { grammarPrompt, missionPrompt, talkPrompt } = await import("../src/learn/talk.ts");
  const plain = talkPrompt(plainReply("I lost it"));
  assert.equal(grammarPrompt(plain, plainReply("I lost it")), plain);
  const opening = missionPrompt(plainStart, "a rescue");
  assert.equal(grammarPrompt(opening, plainStart), opening);
  for (const p of [plain, opening]) assert.doesNotMatch(p.system + p.user, /grammar/i);
});

test("AC-09: a start with a rule invites it in the opening question, as data, never required", async () => {
  const { grammarPrompt, missionPrompt } = await import("../src/learn/talk.ts");
  const req = { ...plainStart, grammar: "Present Perfect" };
  const { system, user } = grammarPrompt(missionPrompt(req, "a rescue"), req);
  assert.match(system, /"grammar" is the grammar rule the learner chose/);
  assert.match(system, /invited, never required/);
  assert.doesNotMatch(system, /grammarVerdict/, "a start answers no learner line");
  assert.equal(JSON.parse(user).grammar, "Present Perfect");
});

test("AC-09, AC-10: a reply with a rule invites it, keeps the target word, fixes gently only after a wrong line and asks for a verdict", async () => {
  const { grammarPrompt, talkPrompt } = await import("../src/learn/talk.ts");
  const req = { ...plainReply("I have lose it"), grammar: "Present Perfect" };
  const { system, user } = grammarPrompt(talkPrompt(req), req);
  assert.match(system, /natural answer needs the target word/, "the target-word rule stays");
  assert.match(system, /invited, never required; a speaking task still needs only its target word/);
  assert.match(system, /Only when it is "wrong", start your reply by repeating the learner's idea in the correct form/);
  assert.match(system, /when it is "right" or "unsure", do not repeat it/);
  assert.match(system, /\{"reply": "your turn", "grammarVerdict": "right" \| "wrong" \| "unsure"\}/);
  assert.deepEqual(JSON.parse(user).grammar, "Present Perfect");

  const mixedReq = { ...req, mode: "mixed" };
  const mixed = grammarPrompt(mixedPrompt(mixedReq, { system: "", user: "" }), mixedReq);
  assert.match(mixed.system, /Also include "grammarVerdict": "right" \| "wrong" \| "unsure"/);
  assert.match(mixed.system, /phrase your questions and speaking tasks so a natural answer could use it/);
  assert.equal(JSON.parse(mixed.user).grammar, "Present Perfect");
});

test("AC-10: the verdict is right, wrong or unsure; anything else, prose, or a picked choice is unsure", async () => {
  const { readGrammarReply, readVerdict } = await import("../src/learn/talk.ts");
  assert.equal(readVerdict("right"), "right");
  assert.equal(readVerdict(" Wrong "), "wrong");
  for (const v of ["maybe", undefined, 1, null]) assert.equal(readVerdict(v), "unsure");
  assert.deepEqual(readGrammarReply('{"reply": "You have lost it? Where?", "grammarVerdict": "wrong"}'), { reply: "You have lost it? Where?", grammarVerdict: "wrong" });
  assert.deepEqual(readGrammarReply("```json\n{\"reply\": \"Where?\", \"grammarVerdict\": \"right\"}\n```"), { reply: "Where?", grammarVerdict: "right" });
  assert.deepEqual(readGrammarReply("Where did you see it?"), { reply: "Where did you see it?", grammarVerdict: "unsure" });
  assert.deepEqual(readGrammarReply('{"grammarVerdict": "right"}'), { reply: "", grammarVerdict: "right" });
});

const postTalk = async (req) => {
  const res = await fetch(`${baseUrl}/learn/talk`, { method: "POST", headers: appHeaders({ "content-type": "application/json" }), body: JSON.stringify(req) });
  return { status: res.status, body: await res.json() };
};

test("AC-10: every plain or mixed reply with a rule returns grammarVerdict for the line it answers", async () => {
  const g = { grammar: "Present Perfect" };
  const right = await postTalk({ ...plainReply("I have lost my boat"), ...g });
  assert.equal(right.status, 200);
  assert.equal(right.body.grammarVerdict, "right");
  assert.equal(right.body.reply, "That sounds lovely. What can you see near the water?");
  assert.equal((await postTalk({ ...plainReply("STUB:wrong I have lose it"), ...g })).body.grammarVerdict, "wrong");
  assert.equal((await postTalk({ ...plainReply("STUB:odd I lost it"), ...g })).body.grammarVerdict, "unsure");
  const prose = await postTalk({ ...plainReply("STUB:prose I lost it"), ...g });
  assert.equal(prose.status, 200);
  assert.deepEqual([prose.body.reply, prose.body.grammarVerdict], ["That sounds lovely. What can you see near the water?", "unsure"]);
  assert.equal((await postTalk({ ...plainReply("STUB:wrong Search the shore", { source: "choice" }), ...g })).body.grammarVerdict, "unsure", "a picked choice is not the learner's line");
  const history = Array.from({ length: 12 }, (_, i) => ({ role: i % 2 ? "learner" : "ai", text: "I have found it" }));
  const last = await postTalk({ ...plainReply("I have found it"), maxReplies: 6, ...g, history });
  assert.equal(last.body.interaction, "complete");
  assert.equal(last.body.grammarVerdict, "right");
  const mixed = await postTalk({ ...plainReply("STUB:wrong I have lose it"), mode: "mixed", ...g });
  assert.equal(mixed.status, 200);
  assert.equal(mixed.body.interaction, "choice");
  assert.equal(mixed.body.grammarVerdict, "wrong");
});

test("AC-09: a start with a rule still plans the mission and returns no verdict; old callers get no verdict", async () => {
  const opening = await postTalk({ ...plainStart, grammar: "Present Perfect" });
  assert.equal(opening.status, 200);
  assert.ok(opening.body.mission);
  assert.equal("grammarVerdict" in opening.body, false);
  const old = await postTalk(plainReply("STUB:wrong I lost it"));
  assert.equal(old.status, 200);
  assert.equal("grammarVerdict" in old.body, false);
  assert.equal(old.body.reply, "That sounds lovely. What can you see near the water?");
  assert.equal((await postTalk({ ...plainReply("I lost it"), grammar: "x".repeat(41) })).status, 400);
});
