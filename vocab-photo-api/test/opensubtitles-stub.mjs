// A local stand-in for the OpenSubtitles REST API (subtitle-frequent-words), in the
// API's own shapes:
//   GET  /subtitles?languages=en&query=...  -> a few results; query "stub empty" -> none,
//                                              "stub error" -> 500
//   POST /download {file_id}                -> {link, file_name, remaining}; file_id 406 -> 406
//                                              (quota used up), 404 -> 404, 413 -> a link to a 1 MB + 1 file
//   GET  /features?query=...                -> a film, a series with two seasons, an episode and a
//                                              title without English subtitles; "stub error" -> 500
//   GET  /files/<id>.srt                    -> a small subtitle file
// `GET /__calls` answers `{ count, last, lastHeaders }`.
import { createServer } from "node:http";

export const STUB_SRT = "1\n00:00:01,000 --> 00:00:03,000\nThe harbour was quiet.\n";

const result = (fileId, extra = {}) => ({
  id: String(fileId),
  type: "subtitle",
  attributes: {
    language: "en",
    download_count: 1000 + fileId,
    hearing_impaired: false,
    machine_translated: false,
    ai_translated: false,
    release: `Release.${fileId}.1080p`,
    feature_details: { title: "Harbour Lights", year: 2024, feature_type: "Movie", feature_id: 501 },
    files: [{ file_id: fileId, file_name: `Release.${fileId}` }],
    ...extra,
  },
});

export const STUB_RESULTS = [
  result(11),
  result(12, {
    hearing_impaired: true,
    feature_details: { title: "The Storm", year: 2025, feature_type: "Episode", parent_title: "Harbour Lights", season_number: 1, episode_number: 4, feature_id: 603, parent_feature_id: 502 },
  }),
  result(13, { language: "fr" }),
  result(14, { machine_translated: true }),
];

export const STUB_FEATURES = [
  { id: "501", type: "feature", attributes: { feature_type: "Movie", title: "harbour lights", title_aka: ["Harbour Lights"], year: "2024", img_url: "https://s8.opensubtitles.com/features/1/0/5/501.jpg", subtitles_counts: { en: 3 } } },
  {
    id: "502", type: "feature",
    attributes: {
      feature_type: "Tvshow", title: "harbour lights", title_aka: ["Harbour Lights"], year: "2025", subtitles_counts: { en: 9 },
      seasons: [{ season_number: 1, episodes: [{}, {}, {}, {}] }, { season_number: 2, episodes: [{}, {}] }],
    },
  },
  { id: "503", type: "feature", attributes: { feature_type: "Episode", title: "the storm", year: "2025", subtitles_counts: { en: 1 } } },
  { id: "504", type: "feature", attributes: { feature_type: "Movie", title: "harbour", year: "1990", subtitles_counts: { fr: 2 } } },
];

export function startOpenSubtitlesStub() {
  const calls = { count: 0, last: null, lastHeaders: null };
  let base = "";
  const server = createServer((req, res) => {
    const url = new URL(req.url, "http://stub");
    const send = (status, body, type = "application/json") => {
      res.writeHead(status, { "content-type": type });
      res.end(typeof body === "string" ? body : JSON.stringify(body));
    };
    if (url.pathname === "/__calls") return send(200, calls);
    let raw = "";
    req.on("data", (chunk) => (raw += chunk));
    req.on("end", () => {
      if (url.pathname.startsWith("/files/")) {
        const id = url.pathname.match(/\/files\/(\d+)\.srt$/)?.[1];
        return send(200, id === "413" ? "x".repeat(1_048_577) : STUB_SRT, "text/plain");
      }
      calls.count += 1;
      calls.last = { path: url.pathname, search: url.search, body: raw ? JSON.parse(raw) : null };
      calls.lastHeaders = { apiKey: req.headers["api-key"] ?? null, userAgent: req.headers["user-agent"] ?? null };
      if (url.pathname === "/features") {
        if (url.searchParams.get("query") === "stub error") return send(500, { message: "stub" });
        return send(200, { data: STUB_FEATURES });
      }
      if (url.pathname === "/subtitles") {
        const query = url.searchParams.get("query");
        if (query === "stub error") return send(500, { message: "stub" });
        return send(200, { total_count: 4, page: 1, data: query === "stub empty" ? [] : STUB_RESULTS });
      }
      if (url.pathname === "/download") {
        const id = JSON.parse(raw || "{}").file_id;
        if (id === 406) return send(406, { message: "You have downloaded your allowed 100 subtitles for 24h" });
        if (id === 404) return send(404, { message: "not found" });
        return send(200, { link: `${base}files/${id}.srt`, file_name: `Release.${id}.srt`, requests: 1, remaining: 99 });
      }
      send(404, { message: "no such route" });
    });
  });
  return new Promise((resolve) => {
    server.listen(0, "127.0.0.1", () => {
      base = `http://127.0.0.1:${server.address().port}/`;
      resolve({ url: base, close: () => server.close() });
    });
  });
}
