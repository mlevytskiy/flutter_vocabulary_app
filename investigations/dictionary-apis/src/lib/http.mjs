// Wall-clock timing around one awaited fetch, including reading the body,
// so `ms` is the time until the caller actually has the response.
// Never throws: failures come back as data ({ status, error }).

const UA = 'vocab-app-dictionary-api-investigation/0.1 (one-off comparison, low volume)';
export const TIMEOUT_MS = 30_000; // long enough to see a Cloudflare 522 rather than our own timeout

export async function timedFetch(url, { headers = {}, binary = false, timeoutMs = TIMEOUT_MS } = {}) {
  const t0 = performance.now();
  try {
    const res = await fetch(url, {
      headers: { 'User-Agent': UA, ...headers },
      signal: AbortSignal.timeout(timeoutMs),
    });
    const body = binary ? await res.arrayBuffer() : await res.text();
    const ms = round(performance.now() - t0);
    const out = { status: res.status, ok: res.ok, ms, body };
    // undici reports a missing reason phrase (e.g. Cloudflare's 522) as "<none>".
    if (!res.ok) out.error = res.statusText && res.statusText !== '<none>' ? res.statusText : `HTTP ${res.status}`;
    return out;
  } catch (e) {
    const ms = round(performance.now() - t0);
    const timeout = e?.name === 'TimeoutError' || e?.name === 'AbortError';
    return {
      status: timeout ? 'timeout' : 'network-error',
      ok: false,
      ms,
      error: timeout ? `no response within ${timeoutMs} ms` : String(e?.cause?.code ?? e?.message ?? e),
    };
  }
}

export function parseJson(text) {
  try {
    return JSON.parse(text);
  } catch {
    return undefined;
  }
}

/** Override a provider's base URL with BASE_URL_<ID> (used to simulate a broken provider). */
export function baseUrl(id, fallback) {
  return process.env[`BASE_URL_${id.toUpperCase().replace(/[^A-Z0-9]/g, '_')}`] ?? fallback;
}

const round = (n) => Math.round(n * 10) / 10;
