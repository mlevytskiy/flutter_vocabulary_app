// The Higgsfield picture adapter: submit a job, poll it until it is done, download the
// picture. All inside the call's one abort signal, so the 120 s limit covers the polling.
//
// API shape per docs.higgsfield.ai (quickstart, requests lifecycle):
//   POST {base}/{model id}              {prompt} + Idempotency-Key -> {request_id, status, status_url}
//   GET  {status_url}                   -> {status: queued | in_progress | completed | failed | nsfw
//                                           | canceled, images?: [{url}]}
//   GET  {images[0].url}                -> the picture
// Auth is `Authorization: Key <HIGGSFIELD_API_KEY>`, where the key is "<key id>:<key secret>";
// the base URL defaults to https://api.higgsfield.ai/ and `HIGGSFIELD_API_URL` overrides it for
// the stub.

import { endpoint } from "./text.ts";
import { sleep, type PictureAdapter } from "./picture.ts";

const DEFAULT_API_URL = "https://api.higgsfield.ai/";

interface Job {
  request_id?: string;
  status?: string;
  status_url?: string;
  images?: { url?: string }[];
}

export const drawWithHiggsfield: PictureAdapter = async ({ model, prompt, apiKey, baseUrl, pollIntervalMs, signal }) => {
  const headers = { authorization: `Key ${apiKey}`, "content-type": "application/json" };

  const submit = await fetch(endpoint(baseUrl, DEFAULT_API_URL, model), {
    method: "POST",
    headers: { ...headers, "idempotency-key": crypto.randomUUID() },
    body: JSON.stringify({ prompt }),
    signal,
  });
  if (!submit.ok) return { failed: "error" };
  const submitted = (await submit.json()) as Job;
  if (!submitted.request_id) return { failed: "error" };

  const statusUrl = submitted.status_url || endpoint(baseUrl, DEFAULT_API_URL, `requests/${submitted.request_id}/status`).href;
  for (;;) {
    const poll = await fetch(statusUrl, { headers, signal });
    if (!poll.ok) return { failed: "error" };
    const job = (await poll.json()) as Job;
    switch (job.status) {
      case "completed": {
        const url = job.images?.[0]?.url;
        if (!url) return { failed: "error" };
        const picture = await fetch(url, { signal });
        if (!picture.ok) return { failed: "error" };
        const bytes = new Uint8Array(await picture.arrayBuffer());
        return { bytes, contentType: picture.headers.get("content-type")?.split(";")[0] || "image/png" };
      }
      case "nsfw":
        return { failed: "refused" };
      case "failed":
      case "canceled":
        return { failed: "error" };
      default:
        await sleep(pollIntervalMs, signal);
    }
  }
};
