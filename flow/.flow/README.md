# This is the delivery road. How to change it without breaking it.

This directory is the netdust-flow pack for this site: the road
(`flows/site.yaml`), its gates (`bin/`), the craft briefs (`craft/`),
the floors, and the tests that hold it all together. The runtime that
drives it is composer-installed (`vendor/netdust/flow`) — nothing in
there is yours to edit; everything in here is.

Read this before editing anything in `.flow/`. The system will refuse
wrong edits with named reasons (lint, pack-tests, arm), but reading
first beats learning by refusal.

## Changing the road — the checklist

1. Edit `flows/site.yaml` — **never** `flows/site.json`. The `.json`
   is a compiled twin; the PreToolUse guard denies editing it, and CI
   fails on a stale one.
2. Recompile the twin:
   `python3 vendor/netdust/flow/bin/flow-lint.py .flow/flows/site.yaml --compile`
3. Run the pack's own tests: `python3 .flow/tests/pack-tests.py`
   (asserts the gate fixtures AND the shape rules below).
4. If you touched PHP fixtures: `python3 .flow/tests/fixture-syntax.py`.
5. Commit **both** files — the `.yaml` and the regenerated `.json`.
6. Arming re-verifies everything (`/flow build/<feature> site` refuses
   with named reasons if the pack is broken) — you do not need to
   pre-verify beyond steps 2–4.

## Three rules every edit must keep

`pack-tests.py` asserts these; an edge added later must not be able to
void them quietly. They ARE the pack's trust claim:

- **Every machine gate routes its red exit back to `build`.** No edge
  carries a failed check forward, ever.
- **`__end__` is reachable only through `gate-acceptance`** — the seal
  gate that reads the human's recorded decision, `--fresh` (an edit
  after approval goes stale and re-asks).
- **Conditions are machine-readable** (`gate.exit == 0` — I1). Prose
  conditions fail the lint.

## Adding a gate

1. Write the check as a script in `.flow/bin/` — exit 0 green, non-zero
   red, `FAIL [name] detail` lines on stdout. Use `bin/tool.sh`: a gate
   whose tool is missing must **FAIL, not skip** — a gate that passes
   when it could not run makes green mean nothing.
2. Add the node to `site.yaml` and wire BOTH edges: green forward, red
   back to `build`. Order gates cheapest-first.
3. Add fixtures to `.flow/tests/pack-tests.py` proving the gate goes
   red on a real defect and green on a clean case. A gate nobody
   tested reports clean because its regex never matched anything.
4. Steps 2–6 of the checklist above.

## The review cluster (I5)

`spec-gate.py` refuses a plan whose `tasks.md` lacks the named review
scopes: one task carrying `review: security`, one carrying
`review: code`. Their build-time check is
`vendor/netdust/flow/bin/review-check.py <feature-dir> <scope>` run
through `attest.py`; the report needs `VERDICT: CLEAN`, the exact
`tree:` hash, and a `reviewer:` identity line. Dispatch reviews to a
fresh-context subagent (see `craft/site-builder.md` § Dispatching the
review cluster) — never review your own work to green them.

## Never

- Edit `flows/site.json`, the run journal, or the marker by hand.
- Write git notes (`git notes …`) yourself — `attest.py` and `seal.py`
  are the only writers; the guard denies the direct path.
- Delete a gate to get past it without deleting its edges too — and
  know that doing so is a decision on the record, reviewed like any
  other diff.
- Weaken a fixture to make `pack-tests.py` pass.

## Per-site tuning (expected, not a violation)

- `render-routes.txt` — every URL that must render. An unlisted route
  is a route nothing checks.
- `floors.yaml` — what THIS codebase declares dangerous; floor hits
  route small work up to the full road.
- `craft/*.md` — the briefs. Prose, but load-bearing prose: the
  walker hands them to the agent at each node.
