"""
MySQL access layer.

Same public API as the old SQLite version (get_connection, init_db,
transaction, execute, execute_rowcount, query_all, query_one), so the
routes / services keep working unchanged. A small translator converts the
few SQLite-isms still in the SQL strings (? placeholders, datetime('now'),
INSERT OR IGNORE, ON CONFLICT ... DO UPDATE) into MySQL syntax.
"""
import os
import re
import sys
from contextlib import contextmanager

import pymysql
from pymysql.constants import CLIENT, FIELD_TYPE
from pymysql.converters import conversions
from pymysql.cursors import DictCursor

sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
import config

# Return DATE / TIME / DATETIME columns as plain strings ("2026-10-22",
# "09:05:00") instead of date/timedelta objects, like SQLite did.
_conv = conversions.copy()
for _t in (FIELD_TYPE.DATE, FIELD_TYPE.TIME, FIELD_TYPE.DATETIME, FIELD_TYPE.TIMESTAMP):
    _conv[_t] = lambda v: v

_OR_IGNORE = re.compile(r"INSERT\s+OR\s+IGNORE", re.I)
_NOW = re.compile(r"datetime\(\s*'now'\s*\)", re.I)
_UPSERT = re.compile(r"ON\s+CONFLICT\s*\([^)]*\)\s*DO\s+UPDATE\s+SET", re.I)
_EXCLUDED = re.compile(r"excluded\.(\w+)", re.I)


def translate(sql):
    sql = _OR_IGNORE.sub("INSERT IGNORE", sql)
    sql = _NOW.sub("NOW()", sql)
    sql = _UPSERT.sub("ON DUPLICATE KEY UPDATE", sql)
    sql = _EXCLUDED.sub(r"VALUES(\1)", sql)
    return sql.replace("?", "%s")


def _connect(database=True):
    return pymysql.connect(
        host=config.MYSQL_HOST,
        port=config.MYSQL_PORT,
        user=config.MYSQL_USER,
        password=config.MYSQL_PASSWORD,
        database=config.MYSQL_DATABASE if database else None,
        charset="utf8mb4",
        cursorclass=DictCursor,
        conv=_conv,
        client_flag=CLIENT.FOUND_ROWS,   # rowcount = rows matched, like SQLite
        autocommit=False,
        init_command="SET SESSION sql_mode=(SELECT REPLACE(@@sql_mode,'ONLY_FULL_GROUP_BY',''))",
    )


class _Conn:
    """Thin wrapper so `conn.execute(...)` / `conn.executemany(...)` work."""

    def __init__(self, raw):
        self._raw = raw

    def execute(self, sql, params=()):
        cur = self._raw.cursor()
        cur.execute(translate(sql), params or None)
        return cur

    def executemany(self, sql, seq):
        cur = self._raw.cursor()
        cur.executemany(translate(sql), list(seq))
        return cur

    def commit(self):
        self._raw.commit()

    def rollback(self):
        self._raw.rollback()

    def close(self):
        self._raw.close()


def ensure_database():
    """Creates the MySQL database if it doesn't exist yet."""
    raw = _connect(database=False)
    try:
        with raw.cursor() as cur:
            cur.execute(f"CREATE DATABASE IF NOT EXISTS `{config.MYSQL_DATABASE}` "
                        "CHARACTER SET utf8mb4")
        raw.commit()
    finally:
        raw.close()


def get_connection():
    return _Conn(_connect())


def init_db():
    """Brings the schema up to date by applying pending migrations."""
    from database.migrate import run_migrations
    return run_migrations()


@contextmanager
def transaction():
    conn = get_connection()
    try:
        yield conn
        conn.commit()
    except Exception:
        conn.rollback()
        raise
    finally:
        conn.close()


def execute(query, params=()):
    conn = get_connection()
    try:
        cur = conn.execute(query, params)
        conn.commit()
        return cur.lastrowid
    finally:
        conn.close()


def execute_rowcount(query, params=()):
    conn = get_connection()
    try:
        cur = conn.execute(query, params)
        conn.commit()
        return cur.rowcount
    finally:
        conn.close()


def query_all(query, params=()):
    conn = get_connection()
    try:
        return conn.execute(query, params).fetchall()
    finally:
        conn.close()


def query_one(query, params=()):
    conn = get_connection()
    try:
        return conn.execute(query, params).fetchone()
    finally:
        conn.close()
