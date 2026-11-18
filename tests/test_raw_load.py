"""Checks that the raw layer holds the Kaggle CSVs unchanged.

Expected row counts are the published sizes of the Olist dataset. A mismatch
usually means a CSV was parsed wrongly (for example, review comments contain
line breaks and quotes), so investigate before changing a number here.
"""

from pathlib import Path

import duckdb
import pytest

DB_PATH = Path(__file__).resolve().parents[1] / "data" / "olist.duckdb"

EXPECTED_ROWS = {
    "orders": 99_441,
    "order_items": 112_650,
    "customers": 99_441,
    "sellers": 3_095,
    "products": 32_951,
    "payments": 103_886,
    "reviews": 99_224,
    "geolocation": 1_000_163,
    "category_translation": 71,
}

pytestmark = pytest.mark.data


@pytest.fixture(scope="module")
def con():
    connection = duckdb.connect(str(DB_PATH), read_only=True)
    yield connection
    connection.close()


@pytest.mark.parametrize("table, expected", EXPECTED_ROWS.items())
def test_raw_row_counts(con, table, expected):
    (actual,) = con.execute(f"SELECT count(*) FROM raw.{table}").fetchone()
    assert actual == expected


def test_raw_columns_are_varchar(con):
    typed = con.execute(
        """
        SELECT table_name, column_name, data_type
        FROM information_schema.columns
        WHERE table_schema = 'raw' AND data_type <> 'VARCHAR'
        """
    ).fetchall()
    assert typed == []
