import assert from "node:assert/strict";
import { test } from "node:test";
import { mixedInteraction, mixedPrompt, readMixedTurn } from "../src/learn/talk-mixed.ts";
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
