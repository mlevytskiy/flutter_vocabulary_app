/**
 * One structured log line per event, read through Workers observability
 * (sad §7). Ids, codes and counts only -- never cell text (sad §8, Logging).
 */
export function logEvent(event: string, fields: Record<string, string | number | boolean | null> = {}): void {
  console.log(JSON.stringify({ event, ...fields }));
}
