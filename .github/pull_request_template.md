## Summary

- What changed:
- Why:

## Required PR Metadata (complete before requesting review)

### Mode (select exactly one)

- [ ] A — Bug Fix
- [ ] B — Feature Delivery
- [ ] C — Safe Refactor
- [ ] D — Performance Optimization
- [ ] E — Test-Only Changes
- [ ] F — Documentation-Only Changes
- [ ] G — Build/CI/Tooling
- [ ] H — Dependency / Version Management
- [ ] I — Security Hardening
- [ ] J — Operations / Config / Data Maintenance

### Scope (allowed files/dirs)

- Allowed paths changed in this PR:
  - 

### Acceptance Criteria

- [ ]
- [ ]

### Tests Run

- `<command>` — `<result>`
- OR: `Not run` — `<reason>`

### Risk Notes

- 

### Rollback Procedure

- 

## Scope Classification

- [ ] UI render/layout
- [ ] TASKENG authority/pathing
- [ ] RemoteExec/Cfg contract

> If more than one box is checked for a hot-file PR, split this PR.

## PR Size Gate

- [ ] Files changed <= 8 (or <= 5 for hot-file PR)
- [ ] Net LOC delta <= 300 (or <= 180 for hot-file PR)
- [ ] Hot files touched <= 2
- [ ] No forced split trigger present

## Hot-File Touches

List any touched hot files:

- [ ] `functions/ui/console/fn_consoleRenderFromSnapshot.sqf`
- [ ] `ui/console/console.hpp`
- [ ] `functions/taskeng/fn_taskengRequestUnitUpdate.sqf`
- [ ] `functions/ui/console/fn_consoleSitrepClear.sqf`
- [ ] `functions/core/fn_coreInitClient.sqf`
- [ ] `description.ext`
- [ ] `CfgFunctions.hpp`

If any checked:

- [ ] Active lock noted in PR/issue comments (`LOCK: <file> until <UTC>`)
- [ ] Conflicts resolved hunk-by-hunk (no "Accept All Current/Incoming")
- [ ] Branch rebased to latest `origin/main` within last 24h

## Required Checks (must be run on latest head SHA)

> CI note: `.github/workflows/arma-preflight.yml` is the authoritative SQF/config lint gate. `sqf-lint.yml` is decommissioned and non-normative.

- [ ] `git fetch origin && git rebase origin/main`
- [ ] `git diff --check`
- [ ] `scripts/dev/check_console_conflicts.sh`
- [ ] `scripts/dev/check_remoteexec_contract.sh`

## Audit Gate Checklist

- [ ] **Syntax/static** passed
- [ ] **Locality/remoteExec** passed
- [ ] **Scheduler/perf** reviewed
- [ ] **Regression scan** reviewed

## Reviewer Notes

- Risk areas:
- Rollback plan:
- Follow-ups (if any):
