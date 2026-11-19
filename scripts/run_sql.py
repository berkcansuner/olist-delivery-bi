"""Print the result of every statement in a .sql file.

Usage: python scripts/run_sql.py sql/profiling/profile_orders.sql

For profiling, not part of the build. The database is opened read-only, so a
profiling query cannot change it. Run build.py first.
"""

import sys
from pathlib import Path

import duckdb

ROOT = Path(__file__).resolve().parents[1]
DB_PATH = ROOT / "data" / "olist.duckdb"


def run_file(con: duckdb.DuckDBPyConnection, path: Path) -> None:
    # DuckDB's own parser splits the file, so a ';' inside a string is safe.
    for statement in con.extract_statements(path.read_text(encoding="utf-8")):
        print(statement.query.strip())
        # No row limit (DuckDB shows 20 by default), and NULL shown apart from ''.
        con.sql(statement.query).show(max_rows=10_000, max_width=10_000, null_value="NULL")


def main() -> None:
    sys.stdout.reconfigure(encoding="utf-8")  # result tables use box-drawing characters
    with duckdb.connect(str(DB_PATH), read_only=True) as con:
        run_file(con, Path(sys.argv[1]))


if __name__ == "__main__":
    main()
