// Finding a subtitle file by film name (subtitle-frequent-words): GET /subtitles/search
// and POST /subtitles/file against the local OpenSubtitles stub (test/opensubtitles-stub.mjs).
import { test } from "node:test";
import assert from "node:assert/strict";
import { appHeaders, baseUrl } from "./helpers.mjs";
import { STUB_SRT } from "./opensubtitles-stub.mjs";

const stubUrl = process.env.VOCAB_API_OPENSUBTITLES_STUB_URL;
const stubCalls = async () => (await fetch(`${stubUrl}__calls`)).json();

const search = async (query, headers = appHeaders()) => {
  const res = await fetch(`${baseUrl}/subtitles/search?query=${encodeURIComponent(query)}`, { headers });
  return { status: res.status, body: await res.json() };
};
const file = async (body, headers = appHeaders({ "content-type": "application/json" })) => {
  const res = await fetch(`${baseUrl}/subtitles/file`, { method: "POST", headers, body: JSON.stringify(body) });
  return { status: res.status, body: await res.json() };
};

test("search: English, human-made files only, with the film or episode details; the key and user agent go to OpenSubtitles", async () => {
  const { status, body } = await search("Harbour Lights");
  assert.equal(status, 200);
  assert.deepEqual(body.results, [
    { fileId: 11, title: "Harbour Lights", year: 2024, show: null, season: null, episode: null, release: "Release.11.1080p", downloads: 1011, hearingImpaired: false, imageUrl: "https://s1.opensubtitles.com/features/1/0/5/501.jpg" },
    { fileId: 12, title: "The Storm", year: 2025, show: "Harbour Lights", season: 1, episode: 4, release: "Release.12.1080p", downloads: 1012, hearingImpaired: true, imageUrl: "https://s1.opensubtitles.com/features/2/0/5/502.jpg" },
  ]);
  const { last, lastHeaders } = await stubCalls();
  assert.equal(last.path, "/subtitles");
  assert.equal(last.search, "?languages=en&query=harbour+lights");
  assert.deepEqual(lastHeaders, { apiKey: "test-key", userAgent: "VocabPhotoApp v1.0" });
});

test("search: nothing found is an empty list; a failing service is subtitles_unavailable", async () => {
  assert.deepEqual((await search("stub empty")).body, { results: [] });
  const failed = await search("stub error");
  assert.equal(failed.status, 502);
  assert.equal(failed.body.code, "subtitles_unavailable");
});

test("search: a query of 1 or over 100 characters is bad_request, and OpenSubtitles is not asked", async () => {
  const before = (await stubCalls()).count;
  for (const query of ["x", "x".repeat(101), "  "]) {
    const { status, body } = await search(query);
    assert.equal(status, 400, JSON.stringify(query));
    assert.equal(body.code, "bad_request");
  }
  assert.equal((await stubCalls()).count, before);
});

test("file: the chosen file comes back as text with its name", async () => {
  const { status, body } = await file({ fileId: 11 });
  assert.equal(status, 200);
  assert.deepEqual(body, { fileName: "Release.11.srt", text: STUB_SRT });
  const { last } = await stubCalls();
  assert.deepEqual(last.body, { file_id: 11, sub_format: "srt" });
});

test("file: quota used up is download_limit (429); gone is not_found; over 1 MB is too_large; a bad id is bad_request", async () => {
  const limit = await file({ fileId: 406 });
  assert.equal(limit.status, 429);
  assert.equal(limit.body.code, "download_limit");
  assert.equal((await file({ fileId: 404 })).body.code, "not_found");
  const big = await file({ fileId: 413 });
  assert.equal(big.status, 413);
  assert.equal(big.body.code, "too_large");
  for (const fileId of [0, -1, 1.5, "11", null]) {
    assert.equal((await file({ fileId })).status, 400, JSON.stringify(fileId));
  }
});

test("both routes need the app secret", async () => {
  assert.equal((await search("Harbour", {})).status, 401);
  assert.equal((await file({ fileId: 11 }, { "content-type": "application/json" })).status, 401);
});

const get = async (path) => {
  const res = await fetch(`${baseUrl}${path}`, { headers: appHeaders() });
  return { status: res.status, body: await res.json() };
};

test("titles: films and series with English subtitles, a series with its seasons and episode counts", async () => {
  const { status, body } = await get("/subtitles/titles?query=Harbour%20Li");
  assert.equal(status, 200);
  assert.deepEqual(body.titles, [
    { featureId: 501, title: "Harbour Lights", year: 2024, series: false, seasons: [], imageUrl: "https://s8.opensubtitles.com/features/1/0/5/501.jpg" },
    { featureId: 502, title: "Harbour Lights", year: 2025, series: true, seasons: [{ season: 1, episodes: 4 }, { season: 2, episodes: 2 }], imageUrl: "https://s1.opensubtitles.com/features/2/0/5/502.jpg" },
  ]);
  const { last } = await stubCalls();
  assert.equal(last.path, "/features");
  assert.equal(last.search, "?query=harbour+li");
});

test("titles: a failing service is subtitles_unavailable; a 1-letter query is bad_request", async () => {
  assert.equal((await get("/subtitles/titles?query=stub%20error")).body.code, "subtitles_unavailable");
  assert.equal((await get("/subtitles/titles?query=h")).status, 400);
});

test("search by a suggested title: a film by its id; a series by its id with the season and episode when given", async () => {
  const cases = [
    ["featureId=501", "?id=501&languages=en"],
    ["featureId=502&series=true", "?languages=en&parent_feature_id=502"],
    ["featureId=502&series=true&season=1", "?languages=en&parent_feature_id=502&season_number=1"],
    ["featureId=502&series=true&season=1&episode=4", "?episode_number=4&languages=en&parent_feature_id=502&season_number=1"],
  ];
  for (const [params, expected] of cases) {
    const { status } = await get(`/subtitles/search?${params}`);
    assert.equal(status, 200, params);
    assert.equal((await stubCalls()).last.search, expected, params);
  }
  for (const params of ["featureId=0", "featureId=x", "featureId=502&series=true&season=0", "featureId=502&series=true&episode=1.5"]) {
    assert.equal((await get(`/subtitles/search?${params}`)).status, 400, params);
  }
});


