import type { RouteContext, RouteDefinition } from "../routing";
import script from "./client/page.js";
import learnScript from "../learn/client/learn.js";
import { STYLE } from "./style";

/**
 * The shared page's static parts (ADR-0002, sad §8): the browser script at a
 * versioned URL with a one-year immutable cache, and the headers every page
 * answer carries. Hashes are computed on first use (a Worker cannot run
 * crypto at module load) and kept for the isolate's life.
 */

interface PageAssets {
  /** `/assets/page-<hash>.js`: the hash changes whenever the script does. */
  scriptPath: string;
  /** `/assets/learn-<hash>.js`: the learn pages' script, hashed the same way. */
  learnScriptPath: string;
  /** `'sha256-…'`, the CSP source that allows the inline <style>. */
  styleSource: string;
}

let assets: Promise<PageAssets> | undefined;

async function sha256(text: string): Promise<Uint8Array> {
  return new Uint8Array(await crypto.subtle.digest("SHA-256", new TextEncoder().encode(text)));
}

async function computeAssets(): Promise<PageAssets> {
  const [scriptHash, learnHash, styleHash] = await Promise.all([sha256(script), sha256(learnScript), sha256(STYLE)]);
  const hex = (hash: Uint8Array) => Array.from(hash.slice(0, 6), (b) => b.toString(16).padStart(2, "0")).join("");
  return {
    scriptPath: `/assets/page-${hex(scriptHash)}.js`,
    learnScriptPath: `/assets/learn-${hex(learnHash)}.js`,
    styleSource: `'sha256-${btoa(String.fromCharCode(...styleHash))}'`,
  };
}

export function pageAssets(): Promise<PageAssets> {
  assets ??= computeAssets();
  return assets;
}

/**
 * Content-Security-Policy for the page and the gone page (sad §8): scripts
 * only from this origin, no inline script; the one inline <style> by hash;
 * images only from this origin; requests to this origin and the browser
 * translation endpoint (ADR-0007). The link is the write credential, so no
 * referrer carries it to another origin.
 */
export async function pageHeaders(): Promise<Record<string, string>> {
  const { styleSource } = await pageAssets();
  return {
    "content-security-policy": [
      "default-src 'none'",
      "script-src 'self'",
      `style-src ${styleSource}`,
      "img-src 'self'",
      "connect-src 'self' https://translate.googleapis.com",
      "base-uri 'none'",
      "form-action 'none'",
      "frame-ancestors 'none'",
    ].join("; "),
    "referrer-policy": "same-origin",
    "x-content-type-options": "nosniff",
  };
}

/**
 * GET /assets/page-<hash>.js and /assets/learn-<hash>.js -- public. Only the
 * current hash answers; an old one (a page rendered before a deploy) is 404
 * rather than new code under an old immutable URL.
 */
function scriptHandler(which: "scriptPath" | "learnScriptPath", source: string) {
  return async ({ url }: RouteContext): Promise<Response> => {
    if (url.pathname !== (await pageAssets())[which]) {
      return new Response("Not found", { status: 404, headers: { "content-type": "text/plain; charset=utf-8" } });
    }
    return new Response(source, {
      status: 200,
      headers: {
        "content-type": "text/javascript; charset=utf-8",
        "cache-control": "public, max-age=31536000, immutable",
        "x-content-type-options": "nosniff",
      },
    });
  };
}

export const assetRoutes: RouteDefinition[] = [
  { method: "GET", pattern: /^\/assets\/page-[0-9a-f]{12}\.js$/, public: true, handler: scriptHandler("scriptPath", script) },
  { method: "GET", pattern: /^\/assets\/learn-[0-9a-f]{12}\.js$/, public: true, handler: scriptHandler("learnScriptPath", learnScript) },
];
