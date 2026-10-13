"""Splits a migration into individual statements using the real PostgreSQL
grammar, and writes them as JSON for tool/apply_one.mjs to execute one by one.

Statement boundaries are taken from the parser's own byte offsets and the
original text is sliced, so each statement keeps its comments and formatting
and stays readable when one of them fails.

Splitting on `$$` and `;` by hand is exactly what goes wrong when a function
body contains a semicolon, which is why this delegates to pglast.

Usage:  python tool/split_statements.py <migration-file>
"""

from __future__ import annotations

import json
import pathlib
import sys

from pglast.parser import parse_sql_json

MIGRATIONS = pathlib.Path(__file__).resolve().parent.parent / "supabase" / "migrations"


def statements_of(sql: str) -> list[str]:
    """Return each top-level statement as its original source text."""
    data = json.loads(parse_sql_json(sql))
    encoded = sql.encode("utf-8")

    out: list[str] = []
    for raw in data["stmts"]:
        start = raw["stmt_location"]
        length = raw["stmt_len"]
        text = encoded[start : start + length].decode("utf-8").strip()
        if text:
            out.append(text if text.endswith(";") else text + ";")
    return out


def main() -> int:
    if len(sys.argv) != 2:
        print("usage: split_statements.py <migration-file>")
        return 2

    path = MIGRATIONS / sys.argv[1]
    statements = statements_of(path.read_text(encoding="utf-8"))

    out = path.with_suffix(".stmts.json")
    out.write_text(json.dumps(statements, ensure_ascii=False), encoding="utf-8")
    print(f"{len(statements)} statements -> {out.name}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())