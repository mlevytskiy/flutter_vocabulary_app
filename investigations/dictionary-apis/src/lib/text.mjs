const ENTITIES = { amp: '&', lt: '<', gt: '>', quot: '"', apos: "'", nbsp: ' ', '#39': "'" };

export function stripHtml(html) {
  return String(html ?? '')
    .replace(/<[^>]*>/g, '')
    .replace(/&(#\d+|#x[0-9a-f]+|\w+);/gi, (m, e) => {
      if (e[0] === '#') {
        const code = e[1].toLowerCase() === 'x' ? parseInt(e.slice(2), 16) : parseInt(e.slice(1), 10);
        return Number.isFinite(code) ? String.fromCodePoint(code) : m;
      }
      return ENTITIES[e.toLowerCase()] ?? m;
    })
    .replace(/\s+/g, ' ')
    .trim();
}

/** Pick BrE / AmE audio from a list of URLs by the dialect marker in the file name/path. */
export function classifyAudio(urls) {
  const audio = { brE: null, amE: null };
  const other = [];
  for (const url of urls) {
    if (!url) continue;
    if (!audio.brE && /[-_/.](uk|gb|british)[-_/.]/i.test(url)) audio.brE = url;
    else if (!audio.amE && /[-_/.](us|american)[-_/.]/i.test(url)) audio.amE = url;
    else other.push(url);
  }
  return { audio, other };
}
