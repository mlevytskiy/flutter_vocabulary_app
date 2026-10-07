export interface Env {
  ANTHROPIC_API_KEY: string;
  /** Overrides the Anthropic API's base URL for subtitle imports; unset in production. The tests point it at a local stub. */
  ANTHROPIC_API_URL?: string;
  /** Overrides the 225 s limit on a subtitle import's AI call, in ms; unset in production. The tests shorten it. */
  SUBTITLE_AI_TIMEOUT_MS?: string;
  /** OpenCode Zen key for the story text step (mnemonic-story). A secret: `wrangler secret put OPENCODE_ZEN_API_KEY`. */
  OPENCODE_ZEN_API_KEY: string;
  /** Overrides OpenCode Zen's base URL; unset in production. The tests point it at a local stub. */
  OPENCODE_ZEN_API_URL?: string;
  /** Overrides the 90 s limit on a story text call, in ms; unset in production. The tests shorten it. */
  STORY_TEXT_TIMEOUT_MS?: string;
  /** xAI key for the story picture step (mnemonic-story). A secret: `wrangler secret put XAI_API_KEY`. */
  XAI_API_KEY: string;
  /** Overrides xAI's base URL; unset in production. The tests point it at a local stub. */
  XAI_API_URL?: string;
  /** Higgsfield key for the story picture step. A secret: `wrangler secret put HIGGSFIELD_API_KEY`. */
  HIGGSFIELD_API_KEY: string;
  /** Overrides Higgsfield's base URL; unset in production. The tests point it at a local stub. */
  HIGGSFIELD_API_URL?: string;
  /** Overrides the 120 s limit on a story picture call, in ms; unset in production. The tests shorten it. */
  STORY_PICTURE_TIMEOUT_MS?: string;
  /** Overrides the Higgsfield polling interval, in ms; unset in production. */
  STORY_PICTURE_POLL_MS?: string;
  APP_SHARED_SECRET: string;
  RATE_LIMITER: { limit: (opts: { key: string }) => Promise<{ success: boolean }> };
  /** Page writes per IP: save cell, add row, delete row, define (good-looking-web, sad §8). */
  PAGE_WRITE_LIMITER: { limit: (opts: { key: string }) => Promise<{ success: boolean }> };
  /** Published sessions as JSON documents, one key per session, 30-day TTL (task-05, D4). */
  SESSIONS: KVNamespace;
  /**
   * Raw bytes of a session's sources (photos today). Never put image bytes in KV.
   * Optional: R2 has to be enabled on the account through the dashboard before
   * the binding can exist; until then the photo routes answer 503 and the rest
   * of the Worker is unaffected.
   */
  SOURCES?: R2Bucket;
  /** Merriam-Webster Collegiate key (definition-mode, ADR-0002). A secret: `wrangler secret put MW_API_KEY`. */
  MW_API_KEY: string;
  /** Overrides the dictionary's base URL; unset in production. The tests point it at a local stub. */
  MW_API_URL?: string;
  /** Successful dictionary lookups, one key per lowercased word, 30-day TTL (sad §7). */
  DEFINITIONS: KVNamespace;
  /** Editable sessions, rows, cell revisions, photo slots and autofill counters (good-looking-web, ADR-0003). Schema in `migrations/`. */
  DB: D1Database;
}
