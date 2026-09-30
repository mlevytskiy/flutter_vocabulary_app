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
