// A D1-shaped database over node:sqlite for unit tests of code that only needs
// `prepare().bind()` and `batch()` -- no `wrangler dev`. It applies the real
// migrations, so the SQL under test runs against the real schema and SQLite's
// own `changes()`. `batch` runs in one transaction, as D1's does.
import { readdirSync, readFileSync } from "node:fs";
import { join, dirname } from "node:path";
import { fileURLToPath } from "node:url";
import { DatabaseSync } from "node:sqlite";

const migrationsDir = join(dirname(fileURLToPath(import.meta.url)), "..", "migrations");

// node:sqlite binds positional values only to plain `?`, so a numbered `?N`
// (D1 style, possibly repeated) is rewritten to `?` with its value copied into place.
function positional(sql, params) {
  const order = [];
  const text = sql.replace(/\?(\d+)/g, (_, n) => {
    order.push(Number(n));
    return "?";
  });
  return { text, values: order.length ? order.map((n) => params[n - 1]) : params };
}

export function sqliteD1() {
  const db = new DatabaseSync(":memory:");
  for (const file of readdirSync(migrationsDir).filter((f) => f.endsWith(".sql")).sort()) {
    db.exec(readFileSync(join(migrationsDir, file), "utf8"));
  }
  const run = ({ sql, params }) => {
    const { text, values } = positional(sql, params);
    const stmt = db.prepare(text);
    if (/^\s*(SELECT|WITH)\b/i.test(sql)) return { results: stmt.all(...values), meta: { changes: 0 } };
    const { changes } = stmt.run(...values);
    return { results: [], meta: { changes: Number(changes) } };
  };
  const statement = (sql, params = []) => ({
    sql,
    params,
    bind: (...values) => statement(sql, values),
    all: async () => run({ sql, params }),
    run: async () => run({ sql, params }),
  });
  return {
    prepare: (sql) => statement(sql),
    async batch(statements) {
      db.exec("BEGIN");
      try {
        const out = statements.map(run);
        db.exec("COMMIT");
        return out;
      } catch (err) {
        db.exec("ROLLBACK");
        throw err;
      }
    },
    /** Direct access for seeding and reading in tests. */
    raw: db,
  };
}
