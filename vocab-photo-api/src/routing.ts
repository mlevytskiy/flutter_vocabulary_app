import type { Env } from "./env";

export interface RouteContext {
  request: Request;
  env: Env;
  url: URL;
  /** Named captures from the route's `pattern`, e.g. `{ id }` for `/s/:id`. */
  params: Record<string, string>;
}

/**
 * One entry in the route table. Every route says for itself whether it is
 * public. The `fetch` handler in `index.ts` applies the shared secret and the
 * rate limiter to every route that does NOT say `public: true` -- so a route
 * added without thinking about it is secret-gated, and making something public
 * is a visible, per-route decision rather than a path check bolted on in one
 * place (see docs/tasks/task-05-publish-session-link.md, "The auth problem").
 */
export interface RouteDefinition {
  method: "GET" | "POST";
  pattern: RegExp;
  public: boolean;
  handler: (ctx: RouteContext) => Promise<Response>;
}

export interface RouteMatch {
  route: RouteDefinition;
  params: Record<string, string>;
}

export type MatchResult = RouteMatch | { methodNotAllowed: true } | undefined;

/**
 * Finds the route for `pathname`. A path that matches some route but with the
 * wrong method reports `methodNotAllowed` so the caller can answer 405 instead
 * of 404.
 */
export function matchRoute(routes: RouteDefinition[], method: string, pathname: string): MatchResult {
  let pathMatched = false;
  for (const route of routes) {
    const m = route.pattern.exec(pathname);
    if (!m) continue;
    pathMatched = true;
    if (route.method !== method) continue;
    return { route, params: { ...(m.groups ?? {}) } };
  }
  return pathMatched ? { methodNotAllowed: true } : undefined;
}
