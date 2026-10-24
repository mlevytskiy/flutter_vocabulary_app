// A local stand-in for OpenAI's speech API, used by the talk voice tests (learn-redesign openai-voice).
// It answers `POST /v1/audio/speech`, chosen by the text:
//   "STUB:error ..."  -> 500
//   "STUB:slow ..."   -> fake mp3 bytes after 3 s (the Worker's test timeout is 1 s)
//   anything else     -> fake mp3 bytes with content-type audio/mpeg
// `GET /__calls` answers `{ count, last, lastAuth, lastPath }`; `last` is the request body.
import { createServer } from "node:http";

/** "ID3" then a few bytes: not playable, but recognisably the stub's. */
export const SPEECH_BYTES = Buffer.from([0x49, 0x44, 0x33, 0x04, 0x00, 0x00, 0x00, 0x00, 0x00, 0x21, 0xff, 0xfb]);

export function startOpenAiStub() {
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
      const text = String(body.input ?? "");
      const audio = () => {
        if (res.destroyed) return;
        res.writeHead(200, { "content-type": "audio/mpeg" });
        res.end(SPEECH_BYTES);
      };
      if (text.startsWith("STUB:error")) {
        res.writeHead(500, { "content-type": "application/json" });
        return res.end(JSON.stringify({ error: { message: "stub" } }));
      }
      if (text.startsWith("STUB:slow")) return void setTimeout(audio, 3000);
      audio();
    });
  });
  return new Promise((resolve) => {
    server.listen(0, "127.0.0.1", () => {
      resolve({ url: `http://127.0.0.1:${server.address().port}/`, close: () => server.close() });
    });
  });
}
