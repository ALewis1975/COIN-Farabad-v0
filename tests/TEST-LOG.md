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
- 2026-02-17T17:42Z | commit: <pending> | Scenario: baseline lint before civ-routing fix (`~/.local/bin/sqflint -e w functions/civsub/fn_civsubContactDialogOpen.sqf`) | Result: PASS | Notes: Target file linted clean before update.
- 2026-02-17T17:43Z | commit: <pending> | Scenario: post-change lint for console-only civ routing (`~/.local/bin/sqflint -e w functions/civsub/fn_civsubContactDialogOpen.sqf`) | Result: PASS | Notes: File remains parse-clean after removing standalone dialog path.
- 2026-02-17T17:43Z | commit: <pending> | Scenario: manual UI verification and screenshot of civ-routing behavior | Result: BLOCKED | Notes: Container has no Arma runtime/display; unable to launch mission UI or capture in-engine screenshot.
- 2026-02-17T17:45Z | commit: <pending> | Scenario: post-review refinement lint (`~/.local/bin/sqflint -e w functions/civsub/fn_civsubContactDialogOpen.sqf`) | Result: PASS | Notes: Console-open guard/refocus update remains parse-clean.
- 2026-02-17T17:55Z | commit: <pending> | Scenario: failing-files remediation triage (`list_workflow_runs` + failed logs for runs `22109256696`/`22109256709`) | Result: PASS | Notes: Preflight failure signature attributed to changed SQF parser-incompatible syntax in `functions/ambiance/fn_airbasePlaneDepart.sqf`; `initServer.sqf` not implicated by logs.
- 2026-02-17T17:56Z | commit: <pending> | Scenario: post-remediation targeted lint (`/home/runner/.local/bin/sqflint -e w functions/civsub/fn_civsubContactDialogOpen.sqf` and `initServer.sqf`) | Result: PASS | Notes: Remaining changed SQF files parse clean; previously failing changed files were reverted to `origin/main` versions.
- 2026-02-17T17:56Z | commit: <pending> | Scenario: manual UI verification/screenshot after failing-files remediation | Result: BLOCKED | Notes: No Arma runtime/display in container; cannot execute mission UI or capture in-engine screenshot.
