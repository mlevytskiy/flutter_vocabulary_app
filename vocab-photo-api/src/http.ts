export const CORS_HEADERS: Record<string, string> = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
  "Access-Control-Allow-Headers": "Content-Type, x-app-secret",
};

export const ALLOWED_MEDIA_TYPES = ["image/jpeg", "image/png", "image/webp"] as const;
export type AllowedMediaType = (typeof ALLOWED_MEDIA_TYPES)[number];

// ~7MB raw grows to ~9.3MB once base64-encoded for Anthropic, comfortably under its 10MB limit.
// The same cap bounds a photo uploaded as a session source, so one number rules both routes.
export const MAX_RAW_BYTES = 7 * 1024 * 1024;

export function jsonResponse(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "content-type": "application/json", ...CORS_HEADERS },
  });
}

export function htmlResponse(html: string, status = 200, extraHeaders: Record<string, string> = {}): Response {
  return new Response(html, {
    status,
    headers: {
      "content-type": "text/html; charset=utf-8",
      // The page will become editable (task-06); a cached copy would show stale words.
      "cache-control": "no-store",
      ...extraHeaders,
    },
  });
}

export function isAllowedMediaType(value: unknown): value is AllowedMediaType {
  return typeof value === "string" && (ALLOWED_MEDIA_TYPES as readonly string[]).includes(value);
}
