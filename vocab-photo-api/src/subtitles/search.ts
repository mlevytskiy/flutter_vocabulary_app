import type { Env } from "../env";
import { jsonResponse } from "../http";
import { logEvent } from "../log";
import type { RouteContext, RouteDefinition } from "../routing";

// Finding a subtitle file by film name (subtitle-frequent-words, 2026-10-14):
// GET /subtitles/titles suggests films and series for what the learner types
// (with each series' seasons and episode counts), GET /subtitles/search asks
// OpenSubtitles for English subtitles -- by the typed name, or by a suggested
// title and, for a series, a season and episode -- and POST /subtitles/file
// fetches one of them as text, so the app can
// import it exactly like a file from the phone. The OpenSubtitles key stays
// on the Worker (the secret `OPENSUBTITLES_API_KEY`); downloads count
// against the key's daily quota (100 a day without a user login). Secret-gated
// and rate-limited by the `fetch` handler like every non-public route.

const DEFAULT_API_URL = "https://api.opensubtitles.com/api/v1/";
/** OpenSubtitles refuses a request without an identifying user agent. */
const USER_AGENT = "VocabPhotoApp v1.0";
const TIMEOUT_MS = 20_000;
const MIN_QUERY_CHARS = 2;
const MAX_QUERY_CHARS = 100;
/** The results shown in the app. */
const MAX_RESULTS = 30;
/** The title suggestions shown in the app. */
const MAX_TITLES = 8;
/** The same 1 MB as the largest file the app accepts (AC-11). */
const MAX_FILE_BYTES = 1_048_576;

type ErrorCode = "bad_request" | "download_limit" | "too_large" | "not_found" | "subtitles_unavailable";
const fail = (status: number, code: ErrorCode, error: string) => jsonResponse({ error, code }, status);

/** One subtitle file the app can offer. */
export interface SubtitleSearchResult {
  fileId: number;
  /** The film's or the episode's title. */
  title: string;
  year: number | null;
  /** The series' name for an episode. */
  show: string | null;
  season: number | null;
  episode: number | null;
  /** The uploader's release name, e.g. "Show.S01E04.1080p.WEB". */
  release: string;
  downloads: number;
  hearingImpaired: boolean;
  /** The film's poster, or the series' for an episode (may be missing: the app hides it). */
  imageUrl: string | null;
}

/**
 * OpenSubtitles' small poster for a film, series or episode: its pictures live at
 * features/<last digit>/<second last>/<third last>/<id>.jpg, and the s1 server serves
 * them all (checked 2026-10-14; a missing one answers 404). Free, no key, no quota.
 */
export function posterUrl(featureId: number | undefined): string | null {
  if (!featureId || !Number.isInteger(featureId) || featureId < 100) return null;
  const id = String(featureId);
  return `https://s1.opensubtitles.com/features/${id[id.length - 1]}/${id[id.length - 2]}/${id[id.length - 3]}/${id}.jpg`;
}

interface SearchReply {
  data?: {
    attributes?: {
      language?: string;
      release?: string;
      download_count?: number;
      hearing_impaired?: boolean;
      machine_translated?: boolean;
      ai_translated?: boolean;
      feature_details?: {
        title?: string;
        year?: number;
        parent_title?: string;
        season_number?: number;
        episode_number?: number;
        feature_type?: string;
        feature_id?: number;
        parent_feature_id?: number;
      };
      files?: { file_id?: number; file_name?: string }[];
    };
  }[];
}

const apiUrl = (env: Env, path: string) => {
  const base = env.OPENSUBTITLES_API_URL || DEFAULT_API_URL;
  return new URL(path, base.endsWith("/") ? base : base + "/");
};

const headers = (env: Env) => ({
  "Api-Key": env.OPENSUBTITLES_API_KEY,
  "User-Agent": USER_AGENT,
  Accept: "application/json",
  "Content-Type": "application/json",
});

/**
 * The English, human-made subtitle files matching [query], as OpenSubtitles
 * ranks them. The query goes lower case with `+` for spaces, the form the API
 * answers without a redirect.
 */
export function readSearchResults(reply: SearchReply): SubtitleSearchResult[] {
  const results: SubtitleSearchResult[] = [];
  for (const item of reply.data ?? []) {
    const a = item.attributes;
    const file = a?.files?.[0];
    if (!a || a.language !== "en" || a.machine_translated || a.ai_translated || typeof file?.file_id !== "number") continue;
    const f = a.feature_details ?? {};
    const isEpisode = f.feature_type === "Episode";
    results.push({
      fileId: file.file_id,
      title: f.title ?? a.release ?? file.file_name ?? "",
      year: f.year ?? null,
      show: isEpisode ? (f.parent_title ?? null) : null,
      season: isEpisode ? (f.season_number ?? null) : null,
      episode: isEpisode ? (f.episode_number ?? null) : null,
      release: a.release ?? file.file_name ?? "",
      downloads: a.download_count ?? 0,
      hearingImpaired: a.hearing_impaired ?? false,
      imageUrl: posterUrl(isEpisode ? (f.parent_feature_id ?? f.feature_id) : f.feature_id),
    });
    if (results.length === MAX_RESULTS) break;
  }
  return results;
}

/** A film or series suggested for what the learner types. */
export interface SubtitleTitle {
  featureId: number;
  title: string;
  year: number | null;
  series: boolean;
  /** For a series: each season and how many episodes it has. */
  seasons: { season: number; episodes: number }[];
  /** Its small poster (may be missing: the app hides it). */
  imageUrl: string | null;
}

interface FeaturesReply {
  data?: {
    id?: string;
    attributes?: {
      feature_type?: string;
      title?: string;
      title_aka?: string[];
      year?: string | number;
      img_url?: string;
      subtitles_counts?: Record<string, number>;
      seasons?: { season_number?: number; episodes?: unknown[] }[];
    };
  }[];
}

/** OpenSubtitles' films and series (not single episodes) that have English subtitles, as it ranks them. */
export function readTitles(reply: FeaturesReply): SubtitleTitle[] {
  const titles: SubtitleTitle[] = [];
  for (const item of reply.data ?? []) {
    const a = item.attributes;
    const featureId = Number(item.id);
    if (!a || !Number.isInteger(featureId) || (a.feature_type !== "Movie" && a.feature_type !== "Tvshow")) continue;
    if (a.subtitles_counts && !a.subtitles_counts.en) continue;
    const series = a.feature_type === "Tvshow";
    // `title` comes lower case; the first plain-letters alias keeps its capitals.
    const title = (a.title_aka ?? []).find((t) => t.toLowerCase() === a.title?.toLowerCase()) ?? a.title ?? "";
    const year = Number(a.year);
    titles.push({
      featureId,
      title,
      year: Number.isInteger(year) && year > 0 ? year : null,
      series,
      seasons: series
        ? (a.seasons ?? [])
            .filter((s) => typeof s.season_number === "number" && s.season_number > 0)
            .map((s) => ({ season: s.season_number!, episodes: s.episodes?.length ?? 0 }))
        : [],
      imageUrl: a.img_url?.startsWith("https://") ? a.img_url : posterUrl(featureId),
    });
    if (titles.length === MAX_TITLES) break;
  }
  return titles;
}

async function handleTitles({ env, url }: RouteContext): Promise<Response> {
  const query = (url.searchParams.get("query") ?? "").trim();
  if (query.length < MIN_QUERY_CHARS || query.length > MAX_QUERY_CHARS) {
    return fail(400, "bad_request", `query must hold ${MIN_QUERY_CHARS} to ${MAX_QUERY_CHARS} characters`);
  }
  const target = apiUrl(env, "features");
  target.search = `query=${plus(query)}`;
  try {
    const response = await fetch(target, { headers: headers(env), signal: AbortSignal.timeout(TIMEOUT_MS) });
    if (!response.ok) throw new Error(`status ${response.status}`);
    return jsonResponse({ titles: readTitles((await response.json()) as FeaturesReply) });
  } catch (err) {
    logEvent("subtitle titles failed", { reason: err instanceof Error ? err.message.slice(0, 120) : "unknown" });
    return fail(502, "subtitles_unavailable", "The subtitle service is not answering, please try again");
  }
}

/** Lower case with `+` for spaces, the form OpenSubtitles answers without a redirect. */
const plus = (text: string) => encodeURIComponent(text.toLowerCase()).replace(/%20/g, "+");

const positive = (value: string | null) => {
  if (value === null) return undefined;
  const n = Number(value);
  return Number.isInteger(n) && n > 0 ? n : null;
};

/**
 * The OpenSubtitles query for a search, its parameters in alphabetical order
 * (the API redirects otherwise): by a suggested title's feature id -- a film's
 * own, or a series' with an optional season and episode -- else by the typed name.
 */
function searchParams(url: URL): string | Response {
  const featureId = positive(url.searchParams.get("featureId"));
  if (featureId === null) return fail(400, "bad_request", "featureId must be a positive whole number");
  if (featureId !== undefined) {
    if (url.searchParams.get("series") !== "true") return `id=${featureId}&languages=en`;
    const season = positive(url.searchParams.get("season"));
    const episode = positive(url.searchParams.get("episode"));
    if (season === null || episode === null) return fail(400, "bad_request", "season and episode must be positive whole numbers");
    return [
      ...(episode ? [`episode_number=${episode}`] : []),
      "languages=en",
      `parent_feature_id=${featureId}`,
      ...(season ? [`season_number=${season}`] : []),
    ].join("&");
  }
  const query = (url.searchParams.get("query") ?? "").trim();
  if (query.length < MIN_QUERY_CHARS || query.length > MAX_QUERY_CHARS) {
    return fail(400, "bad_request", `query must hold ${MIN_QUERY_CHARS} to ${MAX_QUERY_CHARS} characters`);
  }
  return `languages=en&query=${plus(query)}`;
}

async function handleSearch({ env, url }: RouteContext): Promise<Response> {
  const params = searchParams(url);
  if (params instanceof Response) return params;
  const target = apiUrl(env, "subtitles");
  target.search = params;
  let response: Response;
  try {
    response = await fetch(target, { headers: headers(env), signal: AbortSignal.timeout(TIMEOUT_MS) });
  } catch (err) {
    logEvent("subtitle search failed", { reason: err instanceof Error ? err.name : "unknown" });
    return fail(502, "subtitles_unavailable", "The subtitle service is not answering, please try again");
  }
  if (!response.ok) {
    logEvent("subtitle search failed", { status: response.status });
    return fail(502, "subtitles_unavailable", "The subtitle service is not answering, please try again");
  }
  const results = readSearchResults((await response.json()) as SearchReply);
  logEvent("subtitle search", { results: results.length });
  return jsonResponse({ results });
}

async function handleFile({ request, env }: RouteContext): Promise<Response> {
  let fileId: unknown;
  try {
    ({ fileId } = (await request.json()) as { fileId?: unknown });
  } catch {
    return fail(400, "bad_request", "Body must be JSON");
  }
  if (typeof fileId !== "number" || !Number.isInteger(fileId) || fileId <= 0) {
    return fail(400, "bad_request", "fileId must be a positive whole number");
  }
  try {
    const download = await fetch(apiUrl(env, "download"), {
      method: "POST",
      headers: headers(env),
      body: JSON.stringify({ file_id: fileId, sub_format: "srt" }),
      signal: AbortSignal.timeout(TIMEOUT_MS),
    });
    // OpenSubtitles answers 406 when the day's downloads are used up.
    if (download.status === 406 || download.status === 429) {
      logEvent("subtitle file refused", { status: download.status });
      return fail(429, "download_limit", "Today's subtitle downloads are used up. Try again tomorrow or choose a file");
    }
    if (download.status === 404) return fail(404, "not_found", "This subtitle file is gone");
    if (!download.ok) throw new Error(`download status ${download.status}`);
    const { link, file_name: fileName, remaining } = (await download.json()) as { link?: string; file_name?: string; remaining?: number };
    if (!link) throw new Error("no link");
    const file = await fetch(link, { headers: { "User-Agent": USER_AGENT }, signal: AbortSignal.timeout(TIMEOUT_MS) });
    if (!file.ok) throw new Error(`file status ${file.status}`);
    const bytes = new Uint8Array(await file.arrayBuffer());
    if (bytes.length > MAX_FILE_BYTES) return fail(413, "too_large", "This file is too large. The largest file accepted is 1 MB.");
    logEvent("subtitle file", { bytes: bytes.length, remaining: remaining ?? null });
    return jsonResponse({
      fileName: fileName && /\.(srt|vtt)$/i.test(fileName) ? fileName : `${fileName ?? fileId}.srt`,
      text: new TextDecoder().decode(bytes),
    });
  } catch (err) {
    logEvent("subtitle file failed", { reason: err instanceof Error ? err.name + ": " + err.message.slice(0, 120) : "unknown" });
    return fail(502, "subtitles_unavailable", "The subtitle service is not answering, please try again");
  }
}

export const subtitleSearchRoutes: RouteDefinition[] = [
  { method: "GET", pattern: /^\/subtitles\/titles$/, public: false, handler: handleTitles },
  { method: "GET", pattern: /^\/subtitles\/search$/, public: false, handler: handleSearch },
  { method: "POST", pattern: /^\/subtitles\/file$/, public: false, handler: handleFile },
];
