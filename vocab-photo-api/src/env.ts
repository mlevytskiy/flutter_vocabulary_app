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
}
