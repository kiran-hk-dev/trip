"""Static parse check for the Supabase migrations.

pglast wraps the real PostgreSQL parser, so this catches genuine syntax errors
(the class of bug that produces "unexpected end of function definition") without
needing a database. It cannot catch ordering problems or bad references, which
is what a real `supabase db reset` is still needed for.

Usage:  python tool/check_sql.py [--verbose]
"""

from __future__ import annotations

import pathlib
import sys

from pglast import parse_sql
from pglast.parser import ParseError

MIGRATIONS = pathlib.Path(__file__).resolve().parent.parent / "supabase" / "migrations"


def check(path: pathlib.Path) -> list[str]:
    sql = path.read_text(encoding="utf-8")
    try:
        statements = parse_sql(sql)
    except ParseError as err:
        line = getattr(err, "location", None)
        where = f"line {line}: " if line else ""
        return [f"{path.name}: SYNTAX ERROR {where}{err}"]
    return [f"{path.name}: OK ({len(statements)} statements)"]


def main() -> int:
    verbose = "--verbose" in sys.argv
    files = sorted(MIGRATIONS.glob("*.sql"))
    if not files:
        print(f"No migrations found in {MIGRATIONS}")
        return 1

    failed = 0
    for path in files:
        for line in check(path):
            print(line)
            if "ERROR" in line:
                failed += 1
        if verbose:
            statements = parse_sql(path.read_text(encoding="utf-8"))
            for stmt in statements:
                print(f"    {stmt.stmt.__class__.__name__}")

    print()
    print(f"{len(files) - failed}/{len(files)} migrations parse cleanly")
    return 1 if failed else 0


if __name__ == "__main__":
    raise SystemExit(main())