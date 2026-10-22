# SmartAttend on MySQL - setup

1. Create the database + dummy data (pick one):
   - Workbench: open `smartattend_mysql.sql` -> Run
   - or let the app do it: set `.env` and run `python database/seed.py --reset`
2. `pip install -r requirements.txt`
3. Copy `.env.example` to `.env`, set `MYSQL_PASSWORD` (and USER/HOST if different)
4. `python app.py`  ->  login admin / admin123

What changed: `database/db.py` + `database/migrate.py` now use MySQL (PyMySQL),
schema is in `database/migrations_mysql/001_schema.sql`, config has MYSQL_* settings.
A few SQLite-only SQL bits were patched (marks.py, auth_service.py, jobs.py, app.py, seed.py).
Old SQLite migrations are kept in `database/migrations_sqlite_legacy/` for reference.
Note: the tests in tests/ still target SQLite and need updating to run on MySQL.
