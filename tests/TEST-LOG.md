# TEST-LOG

Canonical validation log for this repository.
Append one dated entry per validation pass using:
- Commit/branch
- Scenario and command(s)/steps
- Result: `PASS`, `FAIL`, or `BLOCKED`
- Notes (environment limits, follow-ups)

## Entries

- 2026-02-17 | commit: <pending> | Scenario: container static/docs checks | Result: BLOCKED | Notes: Arma runtime + dedicated/JIP environment unavailable in container; dedicated-server validations deferred.
- 2026-02-17T17:20Z | commit: <pending> | Scenario: CI workflow failure triage (`list_workflow_runs`, failed job logs for runs `22108090044` and `22108056725`) | Result: PASS | Notes: SQF Lint failure is upstream tooling (`pip install sqfvm` package missing); preflight failures are existing sqflint parser incompatibilities, not introduced by this change.
- 2026-02-17T17:31Z | commit: <pending> | Scenario: local baseline tooling (`python -m pip install --upgrade pip && pip install sqflint && pip install sqfvm`) | Result: FAIL | Notes: `sqfvm` cannot be installed in container (`No matching distribution found for sqfvm`), matching CI failure.
- 2026-02-17T17:35Z | commit: <pending> | Scenario: targeted static checks on changed files (`sqflint -e w ...`, config delimiter sanity script) | Result: BLOCKED | Notes: `sqflint` emits known false positives on modern SQF constructs (`#`, `findIf`) in this repo; config balance check passed for `config/CfgFunctions.hpp`.
- 2026-02-17T17:36Z | commit: <pending> | Scenario: manual runtime/UI validation + screenshot capture | Result: BLOCKED | Notes: Arma 3 runtime unavailable in container; unable to execute local MP preview, dedicated/JIP checks, or capture in-engine UI screenshots.
