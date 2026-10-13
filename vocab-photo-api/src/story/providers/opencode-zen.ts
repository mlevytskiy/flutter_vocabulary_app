// The OpenCode Zen text adapter: Zen's OpenAI-compatible chat-completions endpoint
// (https://opencode.ai/zen/v1/chat/completions), with `OPENCODE_ZEN_API_KEY` and the
// `OPENCODE_ZEN_API_URL` override for the stub. The endpoint and model ids are
// provisional until the owner verifies them (models.json).

import { endpoint, type Adapter } from "./text.ts";

const DEFAULT_API_URL = "https://opencode.ai/zen/v1/";

interface ChatReply {
  choices?: { message?: { content?: string | null; refusal?: string | null }; finish_reason?: string | null }[];
  usage?: { prompt_tokens?: number; completion_tokens?: number };
}

export const writeWithZen: Adapter = async ({ model, system, user, apiKey, baseUrl, maxOutputTokens, signal }) => {
  const response = await fetch(endpoint(baseUrl, DEFAULT_API_URL, "chat/completions"), {
    method: "POST",
    headers: { authorization: `Bearer ${apiKey}`, "content-type": "application/json" },
    body: JSON.stringify({
      model,
      max_tokens: maxOutputTokens,
      messages: [
        { role: "system", content: system },
        { role: "user", content: user },
      ],
    }),
    signal,
  });
  if (!response.ok) return { failed: "error" };

  const reply = (await response.json()) as ChatReply;
  const usage = {
    modelId: model,
    inputTokens: reply.usage?.prompt_tokens ?? 0,
    outputTokens: reply.usage?.completion_tokens ?? 0,
  };
  const choice = reply.choices?.[0];
  if (choice?.message?.refusal || choice?.finish_reason === "content_filter") return { failed: "refused", usage };
  if (choice?.finish_reason === "length") return { failed: "error", usage };
  const text = (choice?.message?.content ?? "").trim();
  if (!text) return { failed: "error", usage };
  return { text, usage };
};
