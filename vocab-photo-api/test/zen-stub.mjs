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
//   anything else      -> a short story with token usage
// `GET /__calls` answers `{ count, last, lastAuth }` -- how many calls so far, the last
// request body and its Authorization header -- so a test can tell what was sent.
import { createServer } from "node:http";

export const ZEN_STUB_TEXT = "Ви tackle проблему → ви live up до очікувань";

const completion = (model, message, finish_reason = "stop") => ({
  id: "chatcmpl-stub",
  object: "chat.completion",
  model,
  choices: [{ index: 0, message: { role: "assistant", ...message }, finish_reason }],
  usage: { prompt_tokens: 910, completion_tokens: 275, total_tokens: 1185 },
});

function answer(model, firstLine) {
  switch (firstLine) {
    case "STUB:refusal": return { status: 200, body: completion(model, { content: null, refusal: "I can't help with that." }) };
    case "STUB:filtered": return { status: 200, body: completion(model, { content: "" }, "content_filter") };
    case "STUB:cutoff": return { status: 200, body: completion(model, { content: ZEN_STUB_TEXT }, "length") };
    case "STUB:empty": return { status: 200, body: completion(model, { content: "" }) };
    case "STUB:error": return { status: 500, body: { error: { message: "stub", type: "server_error" } } };
    default: return { status: 200, body: completion(model, { content: ZEN_STUB_TEXT }) };
  }
}

export function startZenStub() {
  const calls = { count: 0, last: null, lastAuth: null, lastPath: null };
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
      calls.lastAuth = req.headers["authorization"] ?? null;
      calls.lastPath = url.pathname;
      const user = body.messages?.find((m) => m.role === "user")?.content;
      const firstLine = typeof user === "string" ? user.split("\n")[0] : "";
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
