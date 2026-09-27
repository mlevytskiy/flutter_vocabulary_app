import assert from "node:assert/strict";
import { randomUUID } from "node:crypto";
import { test } from "node:test";
import { baseUrl, publish } from "./helpers.mjs";

// AC-32: an expired or mistyped link shows the "gone" page — no table, no
// photos, nothing to edit, and nothing that tells whether it ever existed.
test("an unknown session id answers the gone page", async () => {
  const res = await fetch(`${baseUrl}/s/${randomUUID()}`);
  const html = await res.text();

  assert.equal(res.status, 404);
  assert.match(res.headers.get("content-type") ?? "", /text\/html/);
  assert.match(html, /This word list is gone/);
  assert.doesNotMatch(html, /<table/i);
  assert.doesNotMatch(html, /<img/i);
  assert.doesNotMatch(html, /contenteditable/i);
  assert.doesNotMatch(html, /<script/i);
  assert.match(res.headers.get("content-security-policy") ?? "", /default-src 'none'/);
});

// Checks the harness itself: the secret from the dev-vars file opens the
// secret-gated routes, and a published page is not the gone page.
test("a published session is served, not gone", async () => {
  const { id } = await publish();
  const res = await fetch(`${baseUrl}/s/${id}`);

  assert.equal(res.status, 200);
  assert.doesNotMatch(await res.text(), /This word list is gone/);
});
