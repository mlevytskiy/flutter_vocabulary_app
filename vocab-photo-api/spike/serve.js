// T1 spike: serves translate.html so the browser calls the endpoint from a real
// http origin. Not part of the deployed Worker (wrangler.jsonc `main` is
// src/index.ts and nothing imports this folder). Run from vocab-photo-api/:
//   npx wrangler dev -c spike/wrangler.jsonc --ip 0.0.0.0
import page from './translate.html';

export default {
  fetch() {
    return new Response(page, { headers: { 'content-type': 'text/html; charset=utf-8' } });
  },
};
