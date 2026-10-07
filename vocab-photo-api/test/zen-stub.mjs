// A local stand-in for the OpenCode Zen chat-completions API (OpenAI-compatible),
// used by the story text-provider tests (mnemonic-story T4). It answers
// `POST /chat/completions` in the API's own shape, chosen by the first line of the
// user message:
//   "STUB:refusal"     -> a message with `refusal` set
//   "STUB:filtered"    -> finish_reason "content_filter"
//   "STUB:cutoff"      -> finish_reason "length" (a cut-off reply)
//   "STUB:empty"       -> an empty reply
//   "STUB:error"       -> 500
//   "STUB:slow:<ms>"   -> the default reply after <ms> milliseconds
//   "STUB:badjson"     -> prose instead of JSON (only meaningful for the picture prompt writer)
//   anything else      -> a short story with token usage; a picture prompt writer request (its system
//                         prompt names an "image generator") gets valid JSON {character, scenes} with
//                         one scene per numbered caption
// A test can script the next calls: `POST /__script` with a JSON array of markers
// (e.g. ["ok", "STUB:error"]) makes the following calls use them in order, "ok" meaning
// the default reply; `POST /__reset` clears the counters and the script (mnemonic-story T8).
// `GET /__calls` answers `{ count, last, lastAuth }` -- how many calls so far, the last
// request body and its Authorization header -- so a test can tell what was sent.
import { createServer } from "node:http";

export const ZEN_STUB_TEXT = "Ви tackle проблему → ви live up до очікувань";

export const STUB_CHARACTER = "a young adult with short dark hair, a blue jacket, and a backpack";
export const stubScenes = (count) => Array.from({ length: count }, (_, i) => `scene number ${i + 1}`);
export const stubPromptJson = (count) => JSON.stringify({ character: STUB_CHARACTER, scenes: stubScenes(count) });

const completion = (model, message, finish_reason = "stop") => ({
  id: "chatcmpl-stub",
  object: "chat.completion",
  model,
  choices: [{ index: 0, message: { role: "assistant", ...message }, finish_reason }],
  usage: { prompt_tokens: 910, completion_tokens: 275, total_tokens: 1185 },
});

function answer(model, firstLine, captionCount = null) {
  switch (firstLine) {
    case "STUB:refusal": return { status: 200, body: completion(model, { content: null, refusal: "I can't help with that." }) };
    case "STUB:filtered": return { status: 200, body: completion(model, { content: "" }, "content_filter") };
    case "STUB:cutoff": return { status: 200, body: completion(model, { content: ZEN_STUB_TEXT }, "length") };
    case "STUB:empty": return { status: 200, body: completion(model, { content: "" }) };
    case "STUB:error": return { status: 500, body: { error: { message: "stub", type: "server_error" } } };
    case "STUB:badjson": return { status: 200, body: completion(model, { content: "Here is a lovely picture of the story, no JSON." }) };
    default: return { status: 200, body: completion(model, { content: captionCount === null ? ZEN_STUB_TEXT : stubPromptJson(captionCount) }) };
  }
}

export function startZenStub() {
  const calls = { count: 0, last: null, lastAuth: null, lastPath: null };
  let script = [];
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
      if (url.pathname === "/__script") {
        script = Array.isArray(body) ? body : [];
        res.writeHead(204);
        return res.end();
      }
      if (url.pathname === "/__reset") {
        script = [];
        Object.assign(calls, { count: 0, last: null, lastAuth: null, lastPath: null });
        res.writeHead(204);
        return res.end();
      }
      calls.count += 1;
      calls.last = body;
      calls.lastAuth = req.headers["authorization"] ?? null;
      calls.lastPath = url.pathname;
      const user = body.messages?.find((m) => m.role === "user")?.content;
      const scripted = script.shift();
      const firstLine = scripted !== undefined ? (scripted === "ok" ? "" : scripted) : typeof user === "string" ? user.split("\n")[0] : "";
      const slow = firstLine.match(/^STUB:slow:(\d+)$/);
      const system = body.messages?.find((m) => m.role === "system")?.content;
      const captionCount = typeof system === "string" && system.includes("image generator") && typeof user === "string"
        ? (user.match(/^\d+\. /gm) ?? []).length
        : null;
      const { status, body: reply } = answer(body.model, slow ? "" : firstLine, captionCount);
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
