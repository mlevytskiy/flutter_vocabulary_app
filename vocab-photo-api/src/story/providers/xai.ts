// The xAI (Grok) picture adapter: the OpenAI-style image endpoint
// (https://api.x.ai/v1/images/generations), asked for base64, with `XAI_API_KEY` and the
// `XAI_API_URL` override for the stub. The endpoint and model id are provisional until the
// owner verifies them (models.json).

import { endpoint } from "./text.ts";
import type { PictureAdapter } from "./picture.ts";

const DEFAULT_API_URL = "https://api.x.ai/v1/";

interface ImagesReply {
  data?: { b64_json?: string; respect_moderation?: boolean }[];
}

export const drawWithXai: PictureAdapter = async ({ model, prompt, request, apiKey, baseUrl, signal }) => {
  const response = await fetch(endpoint(baseUrl, DEFAULT_API_URL, "images/generations"), {
    method: "POST",
    headers: { authorization: `Bearer ${apiKey}`, "content-type": "application/json" },
    body: JSON.stringify({ ...request, model, prompt, response_format: "b64_json" }),
    signal,
  });
  if (!response.ok) {
    // A prompt the moderation rejects answers 400 and says so.
    const refused = response.status === 400 && /moderat|safety|policy/i.test(await response.text());
    return { failed: refused ? "refused" : "error" };
  }

  const reply = (await response.json()) as ImagesReply;
  const picture = reply.data?.[0];
  if (picture?.respect_moderation === false) return { failed: "refused" };
  if (!picture?.b64_json) return { failed: "error" };
  const bytes = Uint8Array.from(atob(picture.b64_json), (c) => c.charCodeAt(0));
  return { bytes, contentType: sniffContentType(bytes) };
};

/** xAI returns a PNG or a JPEG without saying which. */
function sniffContentType(bytes: Uint8Array): string {
  return bytes[0] === 0xff && bytes[1] === 0xd8 ? "image/jpeg" : "image/png";
}
