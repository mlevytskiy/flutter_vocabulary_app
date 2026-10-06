/// The thin reader script the app runs on a Quizlet set page (ADR-0003).
///
/// It returns one JSON string of raw material and does no interpretation:
///
/// ```
/// { "setId":    the set id the page states (from its address / canonical link),
///   "name":     the set's heading, or the page title,
///   "heading":  the "Terms in this set (N)" heading text,
///   "embedded": the page's embedded data as text, or null,
///   "visible":  the visible term list as rows of side texts, or null,
///   "robot":    title + ids/classes of challenge elements, for the markers }
/// ```
///
/// `parseQuizletPage` (quizlet_set_parser.dart) turns it into a set. The
/// selectors below are the part that follows Quizlet's page; when Quizlet
/// changes it, save a new fixture and fix the script/parser together.
const String quizletPageScript = r'''
(function () {
  function text(el) { return el ? (el.innerText || el.textContent || '').trim() : ''; }
  var out = { setId: null, name: '', heading: '', embedded: null, visible: null, robot: '' };
  try {
    var m = location.pathname.match(/\/(\d{1,20})(?:\/|$)/);
    var canon = document.querySelector('link[rel="canonical"]');
    if (!m && canon) m = (canon.href || '').match(/quizlet\.com\/(?:[a-z-]+\/)?(\d{1,20})(?:\/|$)/);
    out.setId = m ? m[1] : null;
  } catch (e) {}
  try {
    var h1 = document.querySelector('h1');
    out.name = text(h1) || document.title || '';
    var heads = document.querySelectorAll('h2,h3');
    for (var i = 0; i < heads.length; i++) {
      if (/terms in this set/i.test(text(heads[i]))) { out.heading = text(heads[i]); break; }
    }
  } catch (e) {}
  try {
    var nd = document.getElementById('__NEXT_DATA__');
    if (nd && nd.textContent) out.embedded = nd.textContent;
  } catch (e) {}
  try {
    var rows = document.querySelectorAll('[data-testid="set-page-term-card"], [class*="SetPageTerm-content"]');
    if (rows.length) {
      out.visible = [];
      for (var r = 0; r < rows.length; r++) {
        var sides = rows[r].querySelectorAll('[class*="TermText"]');
        var row = [];
        for (var s = 0; s < sides.length; s++) row.push(text(sides[s]));
        out.visible.push(row);
      }
    }
  } catch (e) {}
  try {
    var probe = [document.title || ''];
    var els = document.querySelectorAll('[id*="captcha" i],[class*="captcha" i],[id*="challenge" i],[class*="challenge" i],iframe[src*="captcha" i],iframe[src*="challenge" i]');
    for (var c = 0; c < els.length && c < 20; c++) {
      probe.push((els[c].id || '') + ' ' + (typeof els[c].className === 'string' ? els[c].className : '') + ' ' + (els[c].getAttribute('src') || ''));
    }
    out.robot = probe.join(' | ');
  } catch (e) {}
  return JSON.stringify(out);
})()
''';
