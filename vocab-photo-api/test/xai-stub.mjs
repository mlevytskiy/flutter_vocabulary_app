// A local stand-in for xAI's image API (OpenAI-style), used by the story picture-provider
// tests (mnemonic-story T5). It answers `POST /images/generations`, chosen by the prompt:
//   "STUB:refusal"    -> 200 with `respect_moderation: false` and no picture
//   "STUB:moderated"  -> 400 with a content-moderation error
//   "STUB:error"      -> 500
//   "STUB:empty"      -> 200 with no data
//   "STUB:slow:<ms>"  -> the picture after <ms> milliseconds
//   anything else     -> a picture as base64
// `GET /__calls` answers `{ count, last, lastAuth, lastPath }`.
import { createServer } from "node:http";

export const PICTURE_BYTES = Buffer.from(
  "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==",
  "base64",
);

export function startXaiStub() {
  const calls = { count: 0, last: null, lastAuth: null, lastPath: null };
  const server = createServer((req, res) => {
    const url = new URL(req.url, "http://stub");
    const json = (status, body) => {
      if (res.destroyed) return;
      res.writeHead(status, { "content-type": "application/json" });
      res.end(JSON.stringify(body));
    };
    if (url.pathname === "/__calls") return json(200, calls);
    let raw = "";
    req.on("data", (chunk) => (raw += chunk));
    req.on("end", () => {
      const body = JSON.parse(raw || "{}");
      calls.count += 1;
      calls.last = body;
      calls.lastAuth = req.headers["authorization"] ?? null;
      calls.lastPath = url.pathname;
      const prompt = String(body.prompt ?? "").split("\n")[0];
      const slow = prompt.match(/^STUB:slow:(\d+)$/);
      const picture = { data: [{ b64_json: PICTURE_BYTES.toString("base64"), respect_moderation: true }], model: body.model };
      switch (slow ? "" : prompt) {
        case "STUB:refusal": return json(200, { data: [{ respect_moderation: false }], model: body.model });
        case "STUB:moderated": return json(400, { error: "Generated image rejected by content moderation." });
        case "STUB:error": return json(500, { error: "stub" });
        case "STUB:empty": return json(200, { data: [] });
        default: return slow ? void setTimeout(() => json(200, picture), Number(slow[1])) : json(200, picture);
      }
    });
  });
  return new Promise((resolve) => {
    server.listen(0, "127.0.0.1", () => {
      resolve({ url: `http://127.0.0.1:${server.address().port}/`, close: () => server.close() });
    });
  });
}
