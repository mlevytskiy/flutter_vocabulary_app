// learn-kit: POST /learn/check, the sentence check (spec AC-26, AC-28 – AC-34c; decisions S-19, S-20,
// S-24). The pure rules are tested directly; the route runs against the local Worker, whose AI is
// test/anthropic-stub.mjs.
import assert from "node:assert/strict";
import { test } from "node:test";
import { appHeaders, baseUrl } from "./helpers.mjs";
import { cutNote, parseCheckReply, parseCheckRequest } from "../src/learn/check.ts";

const stubUrl = process.env.VOCAB_API_AI_STUB_URL;
const stubCalls = async () => (await fetch(new URL("__calls", stubUrl))).json();

const post = (body, headers = appHeaders({ "content-type": "application/json" })) =>
  fetch(`${baseUrl}/learn/check`, { method: "POST", headers, body: typeof body === "string" ? body : JSON.stringify(body) });

const ask = (sentence, extra = {}) => ({ word: "walk", translation: "гуляти", sentence, task: "own", extra: "", ...extra });

// ---- the pure rules ----

test("S-20: a valid request is accepted; extra defaults to empty", () => {
  const { word, translation, sentence, task, extra } = ask("I walk every day.");
  assert.deepEqual(parseCheckRequest({ word, translation, sentence, task }), { word, translation, sentence, task, extra });
  for (const task of ["pattern", "own", "translate", "explain"]) assert.equal(parseCheckRequest(ask("I walk.", { task })).error, undefined, task);
});

test("AC-30: empty, one-word, too long, unknown task and story are refused", () => {
  const bad = [
    null,
    ask(""),
    ask("   "),
    ask("Walking"),
    ask("x ".repeat(101)),
    ask(`I walk ${"x".repeat(200)}`),
    ask(`I walk ${"x".repeat(300)}`, { task: "explain" }),
    ask("I walk.", { task: "story" }),
    ask("I walk.", { task: "speak" }),
    ask("I walk.", { word: "" }),
    ask("I walk.", { word: "x".repeat(101) }),
    ask("I walk.", { translation: "x".repeat(201) }),
    ask("I walk.", { extra: "x".repeat(301) }),
    ask("I walk.", { extra: 3 }),
  ];
  for (const body of bad) assert.equal(typeof parseCheckRequest(body).error, "string", JSON.stringify(body)?.slice(0, 80));
  assert.equal(parseCheckRequest(ask(`To walk is ${"x".repeat(280)}`, { task: "explain" })).error, undefined, "explain allows 300");
  assert.equal(parseCheckRequest(ask(`I walk ${"x".repeat(193)}`)).error, undefined, "200 exactly");
});

test("S-20: the reply is a strict JSON object; a fenced block is allowed", () => {
  const reply = { usesWord: true, usesTask: true, ok: false, fixed: "I walked.", note: "Past." };
  assert.deepEqual(parseCheckReply(JSON.stringify(reply)), reply);
  assert.deepEqual(parseCheckReply("```json\n" + JSON.stringify(reply) + "\n```"), reply);
  assert.equal(parseCheckReply("Looks good to me!"), undefined);
  assert.equal(parseCheckReply(JSON.stringify({ ...reply, ok: "yes" })), undefined);
  assert.equal(parseCheckReply(JSON.stringify({ ok: true })), undefined);
  // usesWord and missing strings are tolerated: the Worker computes usesWord itself.
  assert.deepEqual(parseCheckReply(JSON.stringify({ usesTask: true, ok: true })), { usesWord: undefined, usesTask: true, ok: true, fixed: "", note: "" });
});

test("S-20: a note is at most 100 characters, cut at a word", () => {
  assert.equal(cutNote("Short."), "Short.");
  const long = "Use the past simple here because the action finished yesterday, and remember that walk is a regular verb.";
  const cut = cutNote(long);
  assert.ok(cut.length <= 100, cut);
  assert.ok(long.startsWith(cut.replace(/…$/, "")), cut);
  assert.ok(!/\s$/.test(cut));
  assert.equal(cutNote("x".repeat(150)).length, 100);
});

// ---- the route ----

test("AC-26: without the app secret nothing is checked", async () => {
  const before = (await stubCalls()).count;
  assert.equal((await post(ask("I walk home."), { "content-type": "application/json" })).status, 401);
  assert.equal((await stubCalls()).count, before);
});

test("AC-28: a good sentence: ok, nothing fixed; usesWord is the Worker's own match, not the AI's", async () => {
  const before = (await stubCalls()).count;
  const res = await post(ask("I walked home yesterday."));
  assert.equal(res.status, 200);
  // The stub says usesWord false; "walked" is the word by the shared rule (AC-31).
  assert.deepEqual(await res.json(), { usesWord: true, usesTask: true, ok: true, fixed: "", note: "" });
  const calls = await stubCalls();
  assert.equal(calls.count, before + 1);
  assert.equal(calls.last.model, "claude-haiku-4-5-20251001");
  assert.equal(calls.last.max_tokens, 300);
  assert.equal("temperature" in calls.last, false);
  assert.deepEqual(JSON.parse(calls.last.messages[0].content), ask("I walked home yesterday."), "the sentence goes as JSON data");
});

test("AC-31: a sentence without the word reports usesWord false whatever the AI says", async () => {
  const body = await (await post(ask("I strolled home yesterday."))).json();
  assert.equal(body.usesWord, false);
});

test("AC-29: a wrong sentence comes back with one fix and a note of at most 100 characters", async () => {
  const body = await (await post(ask("STUB:wrong I walk home yesterday."))).json();
  assert.equal(body.ok, false);
  assert.equal(body.fixed, "I walked home yesterday.");
  assert.ok(body.note.length > 0 && body.note.length <= 100, body.note);
});

test("AC-33: an explanation never carries a fixed sentence", async () => {
  const body = await (await post(ask("STUB:wrong When you go somewhere on foot.", { task: "explain" }))).json();
  assert.equal(body.fixed, "");
  assert.equal(body.usesWord, false);
});

test("AC-34b: checks are never reused: the same sentence twice asks the AI twice", async () => {
  const before = (await stubCalls()).count;
  await post(ask("We walk to the park."));
  await post(ask("We walk to the park."));
  assert.equal((await stubCalls()).count, before + 2);
});

test("AC-30: a bad request is refused 400 bad_request and reaches nothing", async () => {
  const before = (await stubCalls()).count;
  for (const body of ["not json", ask("Walking"), ask(""), ask("I walk.", { task: "story" })]) {
    const res = await post(body);
    assert.equal(res.status, 400);
    assert.equal((await res.json()).code, "bad_request");
  }
  assert.equal((await stubCalls()).count, before);
});

test("AC-34: an AI that fails, answers unreadably or too late gives 502 check_failed", async () => {
  for (const marker of ["STUB:error", "STUB:malformed", "STUB:slow"]) {
    const res = await post(ask(`${marker} I walk home.`));
    assert.equal(res.status, 502, marker);
    assert.equal((await res.json()).code, "check_failed", marker);
  }
});

test("the check route is POST only", async () => {
  assert.equal((await fetch(`${baseUrl}/learn/check`, { headers: appHeaders() })).status, 405);
});
