"""Rebuild data/olist.duckdb from the raw CSVs.

Usage: python build.py

The database is deleted and rebuilt from scratch on every run, so no state
from an earlier run can leak into the result. SQL files run layer by layer,
and in file-name order within a layer.
"""

import os
from pathlib import Path

import duckdb

ROOT = Path(__file__).resolve().parent
DB_PATH = ROOT / "data" / "olist.duckdb"
LAYERS = ["sql/01_raw"]


def run_sql_file(con: duckdb.DuckDBPyConnection, path: Path) -> None:
    print(f"Running {path.relative_to(ROOT).as_posix()}")
    con.execute(path.read_text(encoding="utf-8"))


def main() -> None:
    os.chdir(ROOT)  # SQL files use paths relative to the repo root
    DB_PATH.unlink(missing_ok=True)
    DB_PATH.with_name(DB_PATH.name + ".wal").unlink(missing_ok=True)
    with duckdb.connect(str(DB_PATH)) as con:
        for layer in LAYERS:
            for path in sorted((ROOT / layer).glob("*.sql")):
                run_sql_file(con, path)
    print(f"Built {DB_PATH.relative_to(ROOT).as_posix()}")


if __name__ == "__main__":
    main()
