"""Checks that scripts/run_sql.py prints the result of every statement in a file."""

import duckdb

from run_sql import run_file


def test_run_file_prints_every_statement(tmp_path, capsys):
    sql_file = tmp_path / "two_queries.sql"
    sql_file.write_text(
        "-- File header.\n"
        "SELECT 'first' || ';result' AS a;\n"
        "\n"
        "-- Second query; its comment must print above its own result.\n"
        "SELECT 40 + 2 AS b;\n",
        encoding="utf-8",
    )
    with duckdb.connect() as con:
        run_file(con, sql_file)
    out = capsys.readouterr().out
    assert out.index("first;result") < out.index("-- Second query") < out.index("42")
