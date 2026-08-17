#!/usr/bin/env python3
"""loop-gate.py — committed shim for the netdust-flow Stop hook.

The real hook lives in the composer-installed runtime
(vendor/netdust/flow). This shim is committed with the site so the
wiring in .claude/settings.json survives a fresh clone; the kernel it
execs is pinned by composer.lock.

Contract: exec the runtime's hook with stdin/argv passed through
untouched. If the runtime is absent (composer install not yet run),
FAIL OPEN — the session behaves like any unharnessed session — but
never silently while a run is armed: an armed marker without a
runtime gets a loud stderr line, because "the loop is driving" must
never be an assumption. Arming itself is impossible without the
runtime (flow-arm.py IS the runtime), so an armed-but-runtimeless
state only occurs when vendor/ was removed after arming.
"""
import os
import sys
from pathlib import Path

# Hooks run from the project root. Bedrock keeps composer.json at the
# root; stackwp keeps it under app/. The clone convention is the
# machine-level fallback.
CANDIDATES = (
    Path("vendor/netdust/flow"),
    Path("app/vendor/netdust/flow"),
    Path(os.path.expanduser("~/.claude/netdust-flow")),
)


def main() -> None:
    for root in CANDIDATES:
        hook = root / "hooks" / "loop-gate.py"
        if hook.exists():
            os.execv(sys.executable,
                     [sys.executable, str(hook)] + sys.argv[1:])
    marker = Path("tasks/.harness-loop.json")
    if marker.exists():
        print("flow: armed marker present but the netdust/flow runtime is "
              "not installed (run `composer install`) — the loop is NOT "
              "driving; stops are not gated", file=sys.stderr)
    sys.exit(0)


if __name__ == "__main__":
    main()
