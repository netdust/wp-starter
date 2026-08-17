#!/usr/bin/env python3
"""fixture-syntax.py — the security gate's fixtures must be real PHP.

pack-tests.py asserts what wp-security.py reports for ~19 snippets. If
one of those snippets had a syntax error, the assertion would still
pass — the scanner is regex-based and does not parse — and we would be
proving the gate's behaviour against code no interpreter would accept.
That is the same defect class as run 0002's fake sort test: a check
that is green for a reason unrelated to the thing it claims to verify.

So: extract every fixture and run `php -l` over it.

    python3 .flow/tests/fixture-syntax.py

Skips (loudly, exit 0) when php is unavailable — unlike the flow gates,
this is a test of the tests, not a gate standing between an agent and a
human decision. CI always has php, which is where it counts.
"""
from __future__ import annotations

import ast
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

TESTS = Path(__file__).resolve().parent / "pack-tests.py"


def fixtures() -> list[tuple[str, str]]:
    """Every `expect(name, php, rules)` call's first two literal args."""
    tree = ast.parse(TESTS.read_text())
    out: list[tuple[str, str]] = []
    for node in ast.walk(tree):
        if (isinstance(node, ast.Call)
                and isinstance(node.func, ast.Name)
                and node.func.id == "expect"
                and len(node.args) >= 2
                and isinstance(node.args[0], ast.Constant)
                and isinstance(node.args[1], ast.Constant)):
            out.append((str(node.args[0].value), str(node.args[1].value)))
    return out


def main() -> int:
    if not shutil.which("php"):
        print("skip  [fixture-syntax]  php unavailable — cannot validate "
              "fixtures locally (CI does)")
        return 0

    cases = fixtures()
    if not cases:
        print("FAIL  [fixture-syntax]  no fixtures found in pack-tests.py — "
              "the extraction broke, which would hide every future error")
        return 1

    failures = []
    with tempfile.TemporaryDirectory() as td:
        for name, php in cases:
            f = Path(td) / "fixture.php"
            f.write_text(php)
            p = subprocess.run(["php", "-l", str(f)],
                               capture_output=True, text=True)
            if p.returncode != 0:
                detail = (p.stdout + p.stderr).strip().splitlines()
                failures.append(f"{name}: {detail[0] if detail else 'invalid'}")

    for f in failures:
        print(f"FAIL  [fixture-syntax]  {f}")
    print(f"fixture-syntax: {len(cases)} fixture(s), {len(failures)} invalid")
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
