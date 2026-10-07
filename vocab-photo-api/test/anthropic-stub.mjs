// A local stand-in for the Anthropic Messages API, started by `scripts/test.mjs`
// and passed to `wrangler dev` as ANTHROPIC_API_URL (subtitle imports only; the
// photo `/analyze` call keeps its own URL). It answers `POST /v1/messages` in the
// API's own shape, chosen by the first subtitle line in the request:
//   "STUB:empty"       -> a complete reply with no words
//   "STUB:no-english"  -> the no-English-lines flag
//   "STUB:cutoff"      -> stop_reason "max_tokens" (a cut-off reply)
//   "STUB:malformed"   -> prose instead of the JSON object
//   "STUB:refusal"     -> stop_reason "refusal"
//   "STUB:error"       -> 500
//   "STUB:slow:<ms>"   -> the default reply after <ms> milliseconds
// A grouping request (its system prompt names "topical groups", user content = JSON {words, keep}, mnemonic-story
// T7) picks its mode from a word that starts "STUB:" and otherwise answers the keep groups
// unchanged plus the other words in even new groups of 7 to 19 (the app's rules):
//   "STUB:small-groups" -> the live bad reply (many groups under 7, invented ids) on the first ask,
//                          a valid split when the request carries `problems` (the retry)
//   "STUB:small-always" -> the bad reply on every ask
//   "STUB:error" / "STUB:refusal" / "STUB:malformed" as above, "STUB:no-groups" -> JSON with no groups
//   anything else      -> 14 ranked candidates, with a case duplicate, for the
//                         route to drop session words and cut to the maximum
// `GET /__calls` answers `{ count, last, lastApiKey }` -- how many calls so far,
// the last request body and its x-api-key -- so a test can tell whether the AI
// was reached.
import { createServer } from "node:http";

export const STUB_WORDS = [
  "reluctant", "tide", "Reluctant", "harbour", "fog", "grab", "rope", "lift",
  "drift", "wary", "shore", "stern", "gale", "moor",
].map((word) => ({
  word,
  translation: `переклад ${word.toLowerCase()}`,
  description: `The meaning of ${word.toLowerCase()}.`,
  context: `A line with ${word.toLowerCase()} in it.`,
}));

const message = (model, text, stop_reason = "end_turn") => ({
  id: "msg_stub",
  type: "message",
  role: "assistant",
  model,
  content: [{ type: "thinking", thinking: "", signature: "stub" }, { type: "text", text }],
  stop_reason,
  usage: { input_tokens: 1200, output_tokens: 340, cache_read_input_tokens: 0, cache_creation_input_tokens: 0 },
});
const list = (words, noEnglish = false) => JSON.stringify({ no_english_lines: noEnglish, words });

function answer(model, firstLine) {
  switch (firstLine) {
    case "STUB:empty": return { status: 200, body: message(model, list([])) };
    case "STUB:no-english": return { status: 200, body: message(model, list([], true)) };
    case "STUB:cutoff": return { status: 200, body: message(model, list(STUB_WORDS).slice(0, 200), "max_tokens") };
    case "STUB:malformed": return { status: 200, body: message(model, "Here are some words: reluctant, tide.") };
    case "STUB:refusal": return { status: 200, body: message(model, "", "refusal") };
    case "STUB:error": return { status: 500, body: { type: "error", error: { type: "api_error", message: "stub" } } };
    default: return { status: 200, body: message(model, list(STUB_WORDS)) };
  }
}

function groupingAnswer(model, content) {
  let request;
  try {
    request = JSON.parse(content);
  } catch {
    return { status: 400, body: { type: "error", error: { type: "invalid_request_error", message: "stub: not JSON" } } };
  }
  const marker = request.words.map((w) => w.word).find((w) => w.startsWith("STUB:"));
  if (marker === "STUB:no-groups") return { status: 200, body: message(model, JSON.stringify({ note: "none" })) };
  const kept = new Set(request.keep.flatMap((g) => g.rowIds));
  const fresh = request.words.map((w) => w.rowId).filter((id) => !kept.has(id));
  const keepGroups = request.keep.map((g) => ({ id: g.id, name: g.name, rowIds: g.rowIds }));
  if (marker === "STUB:small-always" || (marker === "STUB:small-groups" && !request.problems)) {
    // What Haiku really answered: small groups, each with an invented id.
    const groups = [...keepGroups];
    for (let at = 0, i = 0; at < fresh.length; i += 1) {
      const size = [2, 4, 4, 4, 5, 5, 5, 6, 5, 5][i % 10];
      groups.push({ id: `topic${i}`, name: `Topic ${i}`, rowIds: fresh.slice(at, at + size) });
      at += size;
    }
    return { status: 200, body: message(model, JSON.stringify({ groups })) };
  }
  if (marker && marker !== "STUB:small-groups") return answer(model, marker);
  const count = fresh.length < 7 ? 1 : Math.ceil(fresh.length / 19);
  const groups = [...keepGroups];
  for (let i = 0; i < count; i += 1) {
    const from = Math.floor((fresh.length * i) / count);
    const to = Math.floor((fresh.length * (i + 1)) / count);
    if (to > from) groups.push({ name: `Stub group ${i + 1}`, rowIds: fresh.slice(from, to) });
  }
  return { status: 200, body: message(model, "```json\n" + JSON.stringify({ groups }) + "\n```") };
}

export function startAnthropicStub() {
  const calls = { count: 0, last: null, lastApiKey: null };
  const server = createServer((req, res) => {
    const url = new URL(req.url, "http://stub");
    if (url.pathname === "/__calls") {
      res.writeHead(200, { "content-type": "application/json" });
      return res.end(JSON.stringify(calls));
    }
    let raw = "";
    req.on("data", (chunk) => (raw += chunk));
    req.on("end", () => {
      const body = JSON.parse(raw || "{}");
      calls.count += 1;
      calls.last = body;
      calls.lastApiKey = req.headers["x-api-key"] ?? null;
      const content = typeof body.messages?.[0]?.content === "string" ? body.messages[0].content : "";
      if (typeof body.system === "string" && body.system.includes("topical groups")) {
        const { status, body: reply } = groupingAnswer(body.model, content);
        res.writeHead(status, { "content-type": "application/json" });
        return res.end(JSON.stringify(reply));
      }
      const firstLine = content.replace(/^<subtitle_lines>\n/, "").split("\n")[0];
      const slow = firstLine.match(/^STUB:slow:(\d+)$/);
      const { status, body: reply } = answer(body.model, slow ? "" : firstLine);
      const send = () => {
        if (res.destroyed) return;
        res.writeHead(status, { "content-type": "application/json" });
        res.end(JSON.stringify(reply));
      };
      slow ? setTimeout(send, Number(slow[1])) : send();
    });
  });
  return new Promise((resolve) => {
    server.listen(0, "127.0.0.1", () => {
      const url = `http://127.0.0.1:${server.address().port}/`;
      resolve({ url, close: () => server.close() });
    });
  });
}
