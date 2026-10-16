/// The two kinds of tag a collection or a source carries (collection-tags,
/// ADR-0001): an origin tag answers "Where does it come from?", a topic tag
/// "What is it about?". Stored by ordinal, so the order is fixed — origin
/// first — and a new kind is only ever appended.
enum TagKind { origin, topic }
