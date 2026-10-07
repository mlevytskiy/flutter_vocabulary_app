// A local stand-in for Higgsfield's queue API (submit, poll, download), used by the story
// picture-provider tests (mnemonic-story T5). The shape is provisional, as the adapter's:
//   POST /<model id>                  {prompt} -> {request_id, status:"queued", status_url}
//   GET  /requests/<id>/status        -> in_progress ... then completed {images:[{url}]},
//                                        or failed / nsfw
//   GET  /files/<id>.png              -> the picture
// Behaviour comes from the prompt's first line:
//   "STUB:refusal"   -> the job ends nsfw        "STUB:failed"  -> the job ends failed
//   "STUB:error"     -> the submit answers 500   "STUB:nodownload" -> the picture URL answers 404
//   "STUB:slow:<ms>" -> the job completes <ms> after the submit (polls say in_progress before)
//   anything else    -> completes on the second poll
// `GET /__calls` answers `{ submits, polls, last, lastAuth, lastPath }`.
import { createServer } from "node:http";
import { PICTURE_BYTES } from "./xai-stub.mjs";

export function startHiggsfieldStub() {
  const calls = { submits: 0, polls: 0, last: null, lastAuth: null, lastPath: null };
  const jobs = new Map();
  let nextId = 1;
  let base = "";
  const server = createServer((req, res) => {
    const url = new URL(req.url, "http://stub");
    const json = (status, body) => {
      if (res.destroyed) return;
      res.writeHead(status, { "content-type": "application/json" });
      res.end(JSON.stringify(body));
    };
    if (url.pathname === "/__calls") return json(200, calls);

    const status = url.pathname.match(/^\/requests\/([^/]+)\/status$/);
    if (req.method === "GET" && status) {
      calls.polls += 1;
      const job = jobs.get(status[1]);
      if (!job) return json(404, { detail: "not found" });
      job.polls += 1;
      const ready = job.slowMs === null ? job.polls >= 2 : Date.now() - job.at >= job.slowMs;
      if (job.mode === "STUB:refusal") return json(200, { status: "nsfw", request_id: status[1] });
      if (job.mode === "STUB:failed") return json(200, { status: "failed", request_id: status[1] });
      if (!ready) return json(200, { status: "in_progress", request_id: status[1] });
      const file = job.mode === "STUB:nodownload" ? "missing" : status[1];
      return json(200, { status: "completed", request_id: status[1], images: [{ url: `${base}files/${file}.png` }] });
    }
    if (req.method === "GET" && url.pathname.startsWith("/files/")) {
      if (url.pathname === "/files/missing.png") return json(404, {});
      res.writeHead(200, { "content-type": "image/png" });
      return res.end(PICTURE_BYTES);
    }

    let raw = "";
    req.on("data", (chunk) => (raw += chunk));
    req.on("end", () => {
      const body = JSON.parse(raw || "{}");
      calls.submits += 1;
      calls.last = body;
      calls.lastAuth = req.headers["authorization"] ?? null;
      calls.lastPath = url.pathname;
      const prompt = String(body.prompt ?? "").split("\n")[0];
      if (prompt === "STUB:error") return json(500, { detail: "stub" });
      const slow = prompt.match(/^STUB:slow:(\d+)$/);
      const id = String(nextId++);
      jobs.set(id, { mode: prompt, polls: 0, at: Date.now(), slowMs: slow ? Number(slow[1]) : null });
      json(200, { status: "queued", request_id: id, status_url: `${base}requests/${id}/status` });
    });
  });
  return new Promise((resolve) => {
    server.listen(0, "127.0.0.1", () => {
      base = `http://127.0.0.1:${server.address().port}/`;
      resolve({ url: base, close: () => server.close() });
    });
  });
}
