// Copy this file to vocab_api_config.dart (same folder) and fill in your own
// values. vocab_api_config.dart is gitignored — never commit it.

class VocabApiConfig {
  // The Cloudflare Worker URL from `vocab-photo-api`, e.g.
  // https://vocab-photo-api.yoursubdomain.workers.dev
  static const String baseUrl = 'https://vocab-photo-api.example.workers.dev';

  // Must match the APP_SHARED_SECRET you set via:
  // npx wrangler secret put APP_SHARED_SECRET
  static const String appSecret = 'choose-a-long-random-string';
}
