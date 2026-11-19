"""Checks that scripts/run_sql.py prints the result of every statement in a file."""

import duckdb

from run_sql import run_file


def test_run_file_prints_every_statement(tmp_path, capsys):
    sql_file = tmp_path / "two_queries.sql"
    sql_file.write_text(
        "-- a semicolon inside a string must not split the statement\n"
        "SELECT 'first;result' AS a;\n"
        "SELECT 42 AS b;\n",
        encoding="utf-8",
    )
    with duckdb.connect() as con:
        run_file(con, sql_file)
    out = capsys.readouterr().out
    assert "first;result" in out
    assert "42" in out
