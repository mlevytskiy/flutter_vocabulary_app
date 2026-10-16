-- collections-screen: the collection's name as the shared page's title
-- (ADR-0008, sad §4 choice 6, §6 F12; AC-29, AC-30).
-- Promote to vocab-photo-api/migrations/0007_session_title.sql; revert with
-- vocab-photo-api/migrations/down/0007_session_title.sql.
-- NULL means "no title sent": every page published before this feature, and any
-- publish from an older app, keeps the fixed "Vocabulary" heading. Only a create or a
-- republish (POST /sessions) writes it; dialogue and picture deliveries never do.
-- The 1-60 characters, one line rule is checked in code (handlers.ts), as 0001 keeps
-- its text limits in code; the page always renders it through escapeHtml.
ALTER TABLE sessions ADD COLUMN title TEXT;
