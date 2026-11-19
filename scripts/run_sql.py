"""Print the result of every statement in a .sql file.

Usage: python scripts/run_sql.py sql/profiling/profile_orders.sql

For profiling, not part of the build. The database is opened read-only, so a
profiling query cannot change it. Run build.py first.

Put each comment on its own line above the statement it describes; a comment
after the ';' on the same line is not supported.
"""

import sys
from pathlib import Path

import duckdb

ROOT = Path(__file__).resolve().parents[1]
DB_PATH = ROOT / "data" / "olist.duckdb"


def run_file(con: duckdb.DuckDBPyConnection, path: Path) -> None:
    comment: list[str] = []
    # DuckDB's own parser splits the file, so a ';' inside a string is safe.
    for statement in con.extract_statements(path.read_text(encoding="utf-8")):
        # The parser attaches the comment above a statement to the end of the
        # previous one. Move those lines forward, so each comment prints above
        # its own result and the query runs without a trailing comment.
        lines = statement.query.rstrip().splitlines()
        end = len(lines)
        while end and (not lines[end - 1].strip() or lines[end - 1].lstrip().startswith("--")):
            end -= 1
        query = "\n".join(lines[:end])
        print("\n".join(comment + [query]).strip())
        # No row limit (DuckDB shows 20 by default), and NULL shown apart from ''.
        con.sql(query).show(max_rows=10_000, max_width=10_000, null_value="NULL")
        comment = lines[end:]


def main() -> None:
    sys.stdout.reconfigure(encoding="utf-8")  # result tables use box-drawing characters
    with duckdb.connect(str(DB_PATH), read_only=True) as con:
        run_file(con, Path(sys.argv[1]))


if __name__ == "__main__":
    main()
