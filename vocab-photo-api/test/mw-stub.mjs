// A local stand-in for the Merriam-Webster Collegiate API, started by
// `scripts/test.mjs` and passed to `wrangler dev` as MW_API_URL. It answers
// `GET /<word>?key=…` in the dictionary's own format:
//   a word starting with "zz"   -> spelling suggestions only (not found)
//   "outage"                    -> 500 (the dictionary is down)
//   a word starting with "long" -> a first sense over 500 characters, then a short one
//   anything else               -> one sense, "the meaning of <word>", with an example
// `GET /__calls` answers `{ "<word>": count }` of the lookups so far, so a test
// can tell a cache hit from a dictionary call.
import { createServer } from "node:http";

const sense = (text, example) => [
  "sense",
  { dt: [["text", `{bc}${text}`], ...(example ? [["vis", [{ t: example }]]] : [])] },
];
const entry = (word, senses) => [{ meta: { id: word }, fl: "noun", def: [{ sseq: senses.map((s) => [s]) }] }];

function answer(word) {
  if (word.startsWith("zz")) return { status: 200, body: ["zebra", "zest"] };
  if (word === "outage") return { status: 500, body: "Internal Server Error" };
  if (word.startsWith("long")) {
    return { status: 200, body: entry(word, [sense("very ".repeat(120) + "long"), sense(`the short meaning of ${word}`)]) };
  }
  return { status: 200, body: entry(word, [sense(`the meaning of ${word}`, `a {it}${word}{/it} here`)]) };
}

export function startMwStub() {
  const calls = {};
  const server = createServer((req, res) => {
    const url = new URL(req.url, "http://stub");
    if (url.pathname === "/__calls") {
      res.writeHead(200, { "content-type": "application/json" });
      return res.end(JSON.stringify(calls));
    }
    const word = decodeURIComponent(url.pathname.slice(1));
    calls[word] = (calls[word] ?? 0) + 1;
    const { status, body } = answer(word);
    res.writeHead(status, { "content-type": typeof body === "string" ? "text/plain" : "application/json" });
    res.end(typeof body === "string" ? body : JSON.stringify(body));
  });
  return new Promise((resolve) => {
    server.listen(0, "127.0.0.1", () => {
      const url = `http://127.0.0.1:${server.address().port}/`;
      resolve({ url, close: () => server.close() });
    });
  });
}
