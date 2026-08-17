#!/usr/bin/env python3
"""pretooluse-guard.py — committed shim for the netdust-flow PreToolUse
guard (the trust-boundary hook: denies hand-written git notes, twin
edits, journal edits).

Same posture as the loop-gate shim: exec the composer-installed
runtime's guard with stdin passed through; if the runtime is absent,
FAIL OPEN silently — the guard is tamper-resistance, not proof, and a
missing guard leaves the session exactly as safe as any project
without netdust-flow.
"""
import os
import sys
from pathlib import Path

CANDIDATES = (
    Path("vendor/netdust/flow"),
    Path("app/vendor/netdust/flow"),
    Path(os.path.expanduser("~/.claude/netdust-flow")),
)


def main() -> None:
    for root in CANDIDATES:
        hook = root / "hooks" / "pretooluse-guard.py"
        if hook.exists():
            os.execv(sys.executable,
                     [sys.executable, str(hook)] + sys.argv[1:])
    sys.exit(0)


if __name__ == "__main__":
    main()
