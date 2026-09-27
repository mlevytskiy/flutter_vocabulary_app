export interface Env {
  ANTHROPIC_API_KEY: string;
  APP_SHARED_SECRET: string;
  RATE_LIMITER: { limit: (opts: { key: string }) => Promise<{ success: boolean }> };
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
  /** Successful dictionary lookups, one key per lowercased word, 30-day TTL (sad §7). */
  DEFINITIONS: KVNamespace;
  /** Editable sessions, rows, cell revisions, photo slots and autofill counters (good-looking-web, ADR-0003). Schema in `migrations/`. */
  DB: D1Database;
}
