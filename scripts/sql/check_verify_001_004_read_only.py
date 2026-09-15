#!/usr/bin/env python3
"""Fail closed on write-capable SQL before an operator runs verify_001_004.sql."""

from __future__ import annotations

import argparse
from pathlib import Path
import re
import sys


# Only catalog decompilers, privilege readers, and pure built-ins used by the
# committed verifier are permitted. A newly added function needs review.
ALLOWED_FUNCTIONS = {
    "array_length",
    "bool_and",
    "coalesce",
    "count",
    "has_function_privilege",
    "lower",
    "md5",
    "pg_get_constraintdef",
    "pg_get_expr",
    "pg_get_function_result",
    "pg_get_indexdef",
    "regexp_replace",
}
SQL_CALL_KEYWORDS = {"any", "as", "exists", "in"}
WRITE_WORDS = {
    "insert", "update", "delete", "merge", "truncate", "create",
    "alter", "drop", "grant", "revoke", "copy", "call", "do",
    "execute", "refresh", "vacuum", "analyze", "lock", "set",
    "reset", "begin", "commit", "rollback", "prepare", "deallocate",
    "listen", "notify", "unlisten", "comment", "reindex",
}
TOKEN = re.compile(r"[A-Za-z_][A-Za-z_0-9]*")
CALL = re.compile(r"\b([A-Za-z_][A-Za-z_0-9]*(?:\.[A-Za-z_][A-Za-z_0-9]*)?)\s*\(")


class UnsafeSQL(ValueError):
    pass


def executable_sql(source: str) -> str:
    """Blank quoted text/comments while preserving statement punctuation."""
    out: list[str] = []
    i = 0
    state = "code"
    while i < len(source):
        char = source[i]
        nxt = source[i + 1] if i + 1 < len(source) else ""
        if state == "code":
            if char == "'":
                state = "single"
                out.append(" ")
            elif char == '"':
                state = "double"
                out.append(" ")
            elif char == "-" and nxt == "-":
                state = "line"
                out.extend("  ")
                i += 1
            elif char == "/" and nxt == "*":
                raise UnsafeSQL("block comments are prohibited")
            elif char == "$":
                raise UnsafeSQL("dollar-quoted text is prohibited")
            elif char == "\\":
                raise UnsafeSQL("psql backslash commands are prohibited")
            else:
                out.append(char)
        elif state == "line":
            if char == "\n":
                state = "code"
                out.append("\n")
            else:
                out.append(" ")
        elif state == "single":
            if char == "'" and nxt == "'":
                out.extend("  ")
                i += 1
            elif char == "'":
                state = "code"
                out.append(" ")
            else:
                out.append("\n" if char == "\n" else " ")
        else:
            if char == '"' and nxt == '"':
                out.extend("  ")
                i += 1
            elif char == '"':
                state = "code"
                out.append(" ")
            else:
                out.append("\n" if char == "\n" else " ")
        i += 1
    if state in {"single", "double"}:
        raise UnsafeSQL("unterminated quoted literal or identifier")
    return "".join(out)


def check(source: str) -> int:
    code = executable_sql(source)
    if not code.rstrip().endswith(";"):
        raise UnsafeSQL("every executable statement must end with a semicolon")
    statements = [part.strip() for part in code.split(";") if part.strip()]
    if not statements:
        raise UnsafeSQL("no executable SELECT statements")
    for number, statement in enumerate(statements, 1):
        if not re.match(r"^(?:select|with)\b", statement, re.I):
            raise UnsafeSQL(f"statement {number} is not SELECT or WITH...SELECT")
        if re.match(r"^with\b", statement, re.I) and not re.search(
            r"\)\s*select\b", statement, re.I
        ):
            raise UnsafeSQL(f"statement {number} does not finish as SELECT")
        words = {word.lower() for word in TOKEN.findall(statement)}
        forbidden = sorted(words & WRITE_WORDS)
        if forbidden:
            raise UnsafeSQL(f"statement {number} contains write-capable token: {forbidden[0]}")
        if re.search(r"\bselect\b[\s\S]*?\binto\b", statement, re.I):
            raise UnsafeSQL(f"statement {number} contains SELECT INTO")
        if re.search(r"\bfor\s+(?:no\s+key\s+)?(?:key\s+)?(?:update|share)\b", statement, re.I):
            raise UnsafeSQL(f"statement {number} contains row locking")
        calls = {match.group(1).lower() for match in CALL.finditer(statement)}
        unknown = sorted(calls - ALLOWED_FUNCTIONS - SQL_CALL_KEYWORDS)
        if unknown:
            raise UnsafeSQL(f"statement {number} calls unapproved function: {unknown[0]}")
    return len(statements)


def self_test() -> None:
    safe = "SELECT count(*) FROM pg_class WHERE relname = 'safe';"
    assert check(safe) == 1
    unsafe = (
        "WITH changed AS (DELETE FROM public.t RETURNING id) SELECT count(*) FROM changed;",
        "INSERT INTO public.t VALUES (1);",
        "UPDATE public.t SET id = 2;",
        "DELETE FROM public.t;",
        "CREATE TABLE public.t (id integer);",
        "SELECT id INTO public.copy FROM pg_class;",
        "SELECT pg_sleep(1) FROM pg_class;",
        "SELECT id FROM pg_class FOR SHARE;",
        "SELECT 1; DROP TABLE public.t;",
        "SELECT 1 /* hidden */;",
        "SELECT $$hidden$$;",
        "SELECT 'unterminated;",
        "\\dt",
    )
    for case in unsafe:
        try:
            check(case)
        except UnsafeSQL:
            continue
        raise AssertionError(f"unsafe SQL passed: {case}")
    print(f"self-test passed: 1 safe and {len(unsafe)} unsafe cases")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--self-test", action="store_true")
    parser.add_argument("sql_file", nargs="?", default=str(Path(__file__).with_name("verify_001_004.sql")))
    args = parser.parse_args()
    try:
        if args.self_test:
            self_test()
        count = check(Path(args.sql_file).read_text(encoding="utf-8"))
    except (UnsafeSQL, OSError, AssertionError) as error:
        print(f"read-only gate FAILED: {error}", file=sys.stderr)
        return 1
    print(f"read-only gate passed: {count} SELECT statement(s) in {args.sql_file}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
