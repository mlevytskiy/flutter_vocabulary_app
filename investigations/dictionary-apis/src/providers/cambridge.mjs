import { baseUrl } from '../lib/http.mjs';
import { skipped } from '../lib/result.mjs';
import { probeIdm } from '../lib/idm.mjs';

// Manual-approval key; unverified.
export const id = 'cambridge';
const BASE = baseUrl(id, 'https://dictionary-api.cambridge.org');

export async function probe(word) {
  const key = process.env.CAMBRIDGE_KEY;
  if (!key) return skipped('no key');
  return probeIdm({ base: BASE, dictCode: 'british', key, word });
}
