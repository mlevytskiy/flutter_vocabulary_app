/// A Quizlet set found in pasted text: its id and the plain address
/// `https://quizlet.com/<id>/<name>/` (no language part, no sharing extras).
class QuizletSetLink {
  const QuizletSetLink({required this.setId, required this.plainUrl});

  final String setId;
  final String plainUrl;

  @override
  bool operator ==(Object other) =>
      other is QuizletSetLink &&
      other.setId == setId &&
      other.plainUrl == plainUrl;

  @override
  int get hashCode => Object.hash(setId, plainUrl);

  @override
  String toString() => 'QuizletSetLink($setId, $plainUrl)';
}

/// Pure rules for Quizlet links: finding a set link in pasted text (AC-02,
/// AC-06, AC-13) and deciding which web view navigations may be followed
/// (AC-11, ADR-0004). The plain link has exactly the form the Worker accepts:
/// `https://quizlet.com/<digits up to 20>/<name>/`.
class QuizletLink {
  QuizletLink._();

  // A language part such as `ar` or `pt-br`.
  static const String _lang = r'[a-z]{2}(?:-[a-z]{2,4})?';

  // The link must start at a word boundary of its own, so another site's
  // address that merely contains `quizlet.com/...` is not taken for a link.
  static final RegExp _setLink = RegExp(
    r'(?<![\p{L}\p{N}_./@=%~-])(?:https?://)?(?:www\.)?quizlet\.com/'
    '(?:$_lang/)?(\\d{1,20})/([\\p{L}\\p{N}_%.~-]+)',
    caseSensitive: false,
    unicode: true,
  );

  static final RegExp _langSegment = RegExp('^$_lang\$', caseSensitive: false);
  static final RegExp _digits = RegExp(r'^\d{1,20}$');

  /// The first Quizlet set link in [text], or null when there is none
  /// (another site, a folder or class link, or plain words).
  static QuizletSetLink? find(String text) {
    for (final match in _setLink.allMatches(text)) {
      final setId = match.group(1)!;
      final name = match.group(2)!.replaceFirst(RegExp(r'\.+$'), '');
      if (name.isEmpty) continue;
      return QuizletSetLink(
          setId: setId, plainUrl: 'https://quizlet.com/$setId/$name/');
    }
    return null;
  }

  /// The set id of a Quizlet set page address (with or without a language
  /// part), or null for any other address.
  static String? setIdOf(Uri uri) {
    final segments = uri.pathSegments;
    var i = 0;
    if (segments.length >= 2 && _langSegment.hasMatch(segments[0])) i = 1;
    if (i < segments.length && _digits.hasMatch(segments[i])) {
      return segments[i];
    }
    return null;
  }

  /// Whether the web view may follow a navigation to [uri] while reading the
  /// set [setId]: only https pages of quizlet.com (or a subdomain), and of
  /// those only pages that are not another set's page.
  static bool isNavigationAllowed(Uri uri, String setId) {
    if (uri.scheme != 'https') return false;
    if (uri.userInfo.isNotEmpty) return false;
    if (uri.hasPort && uri.port != 443) return false;
    final host = uri.host;
    if (host != 'quizlet.com' && !host.endsWith('.quizlet.com')) return false;
    final pageSetId = setIdOf(uri);
    return pageSetId == null || pageSetId == setId;
  }
}
