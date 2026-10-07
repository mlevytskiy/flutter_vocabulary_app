// The Anthropic text adapter: the Messages API, with the app's existing key and
// `ANTHROPIC_API_URL` override (as subtitle imports use them).

import { endpoint, type Adapter } from "./text.ts";

const DEFAULT_API_URL = "https://api.anthropic.com/";

interface MessagesReply {
  content?: { type: string; text?: string }[];
  stop_reason?: string;
  usage?: { input_tokens?: number; output_tokens?: number };
}

export const writeWithAnthropic: Adapter = async ({ model, system, user, apiKey, baseUrl, maxOutputTokens, signal }) => {
  const response = await fetch(endpoint(baseUrl, DEFAULT_API_URL, "v1/messages"), {
    method: "POST",
    headers: { "x-api-key": apiKey, "anthropic-version": "2023-06-01", "content-type": "application/json" },
    body: JSON.stringify({ model, max_tokens: maxOutputTokens, system, messages: [{ role: "user", content: user }] }),
    signal,
  });
  if (!response.ok) return { failed: "error" };

  const reply = (await response.json()) as MessagesReply;
  const usage = {
    modelId: model,
    inputTokens: reply.usage?.input_tokens ?? 0,
    outputTokens: reply.usage?.output_tokens ?? 0,
  };
  if (reply.stop_reason === "refusal") return { failed: "refused", usage };
  // A cut-off story would fail the word check anyway; say why instead.
  if (reply.stop_reason === "max_tokens") return { failed: "error", usage };
  const text = (reply.content ?? [])
    .filter((block) => block.type === "text")
    .map((block) => block.text ?? "")
    .join("")
    .trim();
  if (!text) return { failed: "error", usage };
  return { text, usage };
};
