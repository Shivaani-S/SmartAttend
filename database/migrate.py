"""
Minimal versioned migration runner for MySQL.

Numbered .sql files in database/migrations_mysql/ are applied once each and
recorded in `schema_migrations`.   Usage:  python database/migrate.py
"""
import os
import sys

sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
import config
from database.db import ensure_database, get_connection


def _migration_files():
    if not os.path.isdir(config.MIGRATIONS_DIR):
        return []
    return sorted(f for f in os.listdir(config.MIGRATIONS_DIR) if f.endswith(".sql"))


def _statements(text):
    lines = [l for l in text.splitlines() if not l.strip().startswith("--")]
    return [s.strip() for s in "\n".join(lines).split(";") if s.strip()]


def run_migrations():
    """Applies pending migrations in order. Returns the list applied."""
    ensure_database()
    conn = get_connection()
    applied = []
    try:
        conn.execute("CREATE TABLE IF NOT EXISTS schema_migrations ("
                     "version VARCHAR(32) PRIMARY KEY, "
                     "applied_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP)")
        done = {r["version"] for r in conn.execute("SELECT version FROM schema_migrations").fetchall()}
        for filename in _migration_files():
            version = filename.split("_", 1)[0]
            if version in done:
                continue
            with open(os.path.join(config.MIGRATIONS_DIR, filename), "r", encoding="utf-8") as f:
                for stmt in _statements(f.read()):
                    conn.execute(stmt)
            conn.execute("INSERT INTO schema_migrations (version) VALUES (?)", (version,))
            conn.commit()
            applied.append(filename)
    finally:
        conn.close()
    return applied


if __name__ == "__main__":
    applied = run_migrations()
    print("Applied:", ", ".join(applied) if applied else "nothing (already up to date)")
