// learn-welcome T8 (AC-13): the talk mission takes a topic, a reply limit (6 or 12) and keeps the
// app's chosen words; without the new fields a talk is what it was.
import assert from "node:assert/strict";
import { test } from "node:test";
import { mixedInteraction, mixedPrompt } from "../src/learn/talk-mixed.ts";
import { isLastTurn, missionPrompt, parseTalkRequest, readMission } from "../src/learn/talk.ts";
import { appHeaders, baseUrl } from "./helpers.mjs";

const words = ["shore", "tide", "fog", "gale", "pier", "anchor", "mast", "deck"].map((word) => ({ word, translation: "t" }));
const start = { kind: "start", mode: "mixed", scene: "Sea words", words, target: "shore", history: [] };
const replies = (n) => Array.from({ length: n * 2 }, (_, i) => ({ role: i % 2 ? "learner" : "ai", text: `line ${i}` }));
const reply = (n, extra = {}) => ({ ...start, kind: "reply", history: replies(n), ...extra });

test("the new fields parse; a topic is trimmed, at most 80 characters, with an optional id", () => {
  const parsed = parseTalkRequest({ ...start, topic: { id: "travel", text: "  Travel  " }, maxReplies: 6 });
  assert.deepEqual(parsed.topic, { id: "travel", text: "Travel" });
  assert.equal(parsed.maxReplies, 6);
  assert.deepEqual(parseTalkRequest({ ...start, topic: { text: "x".repeat(80) } }).topic, { text: "x".repeat(80) });
  for (const topic of [{ text: "x".repeat(81) }, { text: "   " }, {}, "Travel", { id: 3, text: "Travel" }, { id: "", text: "Travel" }]) {
    assert.match(parseTalkRequest({ ...start, topic }).error, /topic/i, JSON.stringify(topic));
  }
  for (const maxReplies of [0, 9, "6", 7, null]) assert.equal(parseTalkRequest({ ...start, maxReplies }).error, "maxReplies must be 6 or 12");
  assert.equal(parseTalkRequest(reply(7, { maxReplies: 6 })).error, "The talk ended after 6 replies");
  assert.equal(parseTalkRequest(reply(6, { maxReplies: 6 })).error, undefined);
});

test("without the new fields the request, the mission prompt and the rounds are unchanged", () => {
  const parsed = parseTalkRequest(start);
  assert.deepEqual(parsed, start);
  const { system, user } = missionPrompt(parsed, "a rescue");
  assert.match(system, /pick 4-6 of the words/);
  assert.doesNotMatch(system, /missionTopic/);
  assert.equal(JSON.parse(user).missionTopic, undefined);
  assert.match(mixedPrompt(reply(1), { system: "", user: "" }).system, /Three rounds, nine learner actions total/);
  assert.equal(mixedInteraction(reply(6)), "choice");
  assert.equal(mixedInteraction(reply(9)), "complete");
  assert.equal(isLastTurn(parseTalkRequest({ ...reply(12), mode: undefined })), false);
});

test("a topic leads the mission and a reply limit keeps every chosen word", () => {
  const req = parseTalkRequest({ ...start, topic: { text: "Ordering at a cafe" }, maxReplies: 12 });
  const { system, user } = missionPrompt(req, "a rescue");
  assert.equal(JSON.parse(user).missionTopic, "Ordering at a cafe");
  assert.match(system, /missionTopic/);
  assert.match(system, /all of the words/);
  // The mixed start's own rewording still applies and does not bring back the pick of 4-6.
  assert.doesNotMatch(mixedPrompt(req, { system, user }).system, /pick [45]-6/);
  const plan = JSON.stringify({ title: "T", role: "R", goal: "G", brief: "B", opening: "O?", picture: "P", words: ["tide"] });
  assert.deepEqual(readMission(plan, words, true).mission.words, words.map((w) => w.word));
  assert.deepEqual(readMission(plan, words).mission.words, ["tide"]);
});

test("a reply limit sets the talk's length: Easy ends after 6 replies, Hard after 12", () => {
  assert.deepEqual(Array.from({ length: 7 }, (_, n) => mixedInteraction(reply(n, { maxReplies: 6 }))),
    ["choice", "choice", "speak", "choice", "choice", "speak", "complete"]);
  assert.equal(mixedInteraction(reply(9, { maxReplies: 12 })), "choice");
  assert.equal(mixedInteraction(reply(11, { maxReplies: 12 })), "speak");
  assert.equal(mixedInteraction(reply(12, { maxReplies: 12 })), "complete");
  assert.match(mixedPrompt(reply(1, { maxReplies: 6 }), { system: "", user: "" }).system, /2 rounds, 6 learner actions total/);
  assert.match(mixedPrompt(reply(1, { maxReplies: 12 }), { system: "", user: "" }).system, /4 rounds, 12 learner actions total/);
  const plain = (n) => parseTalkRequest({ ...reply(n), mode: undefined, maxReplies: 6 });
  assert.equal(isLastTurn(plain(5)), false);
  assert.equal(isLastTurn(plain(6)), true);
});

const post = async (req) => {
  const response = await fetch(`${baseUrl}/learn/talk`, { method: "POST", headers: appHeaders({ "content-type": "application/json" }), body: JSON.stringify(req) });
  return { status: response.status, body: await response.json() };
};

test("route: a start with a topic and a limit keeps every chosen word; the 6th reply ends the talk; a 7th is refused", async () => {
  const opening = await post({ ...start, topic: { id: "sea", text: "A day at sea" }, maxReplies: 6 });
  assert.equal(opening.status, 200);
  assert.deepEqual(opening.body.mission.words, words.map((w) => w.word));
  assert.equal(opening.body.target, "shore");
  const fifth = await post(reply(5, { maxReplies: 6 }));
  assert.equal(fifth.body.interaction, "speak");
  const end = await post(reply(6, { maxReplies: 6 }));
  assert.equal(end.status, 200);
  assert.equal(end.body.interaction, "complete");
  assert.match(end.body.reply, /found your boat/);
  const after = await post(reply(7, { maxReplies: 6 }));
  assert.equal(after.status, 400);
  assert.equal(after.body.code, "bad_request");
  const bad = await post({ ...start, topic: { text: "x".repeat(81) } });
  assert.equal(bad.status, 400);
});

test("route: a plain talk with a limit ends with a complete turn; without one it does not", async () => {
  const plain = { ...reply(6), mode: undefined };
  delete plain.mode;
  const end = await post({ ...plain, maxReplies: 6 });
  assert.equal(end.status, 200);
  assert.equal(end.body.interaction, "complete");
  assert.deepEqual(end.body.choices, []);
  assert.match(end.body.reply, /boat is back/);
  const open = await post(plain);
  assert.equal(open.status, 200);
  assert.equal(open.body.interaction, undefined);
});
