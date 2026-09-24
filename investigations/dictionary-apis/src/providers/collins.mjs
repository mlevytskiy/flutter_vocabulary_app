import { baseUrl } from '../lib/http.mjs';
import { skipped } from '../lib/result.mjs';
import { probeIdm } from '../lib/idm.mjs';

// Manual-approval key; unverified.
export const id = 'collins';
const BASE = baseUrl(id, 'https://api.collinsdictionary.com');

export async function probe(word) {
  const key = process.env.COLLINS_KEY;
  if (!key) return skipped('no key');
  return probeIdm({ base: BASE, dictCode: 'english', key, word });
}
