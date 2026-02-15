# Farabad Console — Regression & Git Conflict Runbook

**Purpose:** Stop repeated hotfix loops by separating (1) runtime UI diagnosis from (2) merge/conflict hygiene.

## 1) Root-cause loop (do this before hotfixing)

1. **Enable layout diagnostics in mission runtime**
   - In debug console / init, set:
     - `missionNamespace setVariable ["ARC_console_layout_audit", true];`
2. **Exercise the exact failing flow**
   - Open console → complete task → submit SITREP → check S3/TOC views.
3. **Collect audit logs**
   - Look for:
     - `CONSOLE_LAYOUT_AUDIT_FAIL`
     - `CONSOLE_LAYOUT_AUDIT_OK`
   - Fail logs include:
     - out-of-bounds controls (cutoff risk)
     - overlapping visible controls (frame/content collision)
4. **Only patch files implicated by logs**
   - Avoid broad render rewrites.
   - Keep changes small and idempotent.

## 2) Pre-merge conflict hygiene (to prevent false regressions)

Before opening or merging a PR:

1. Rebase/merge latest target branch.
2. Run:
   - `scripts/dev/check_console_conflicts.sh`
3. If conflicts exist in console-critical files:
   - Resolve **hunk-by-hunk** (never "Accept All Current" / "Accept All Incoming").
   - Prefer preserving verified behavior and diagnostic hooks.
4. Run quick checks:
   - `git diff --check`
   - `scripts/dev/check_console_conflicts.sh`

## 3) Conflict resolution policy for console files

For these files, resolve manually:

- `functions/ui/console/fn_consoleRenderFromSnapshot.sqf`
- `ui/console/console.hpp`
- `functions/taskeng/fn_taskengRequestUnitUpdate.sqf`
- `functions/ui/console/fn_consoleSitrepClear.sqf`
- `functions/core/fn_coreInitClient.sqf`

### Always keep if present

- render single-flight / queued rerender lifecycle
- explicit onLoad/onUnload namespace init/cleanup for console state
- SITREP field normalization before request send
- layout audit hook (`ARC_fnc_consoleAuditLayout`)

## 4) Definition of done for console hotfixes

A hotfix is complete only when all are true:

- No unresolved merge markers in console-critical files.
- Console opens/closes without duplicate/overlap behavior.
- SITREP submission preserves selected LACE values.
- S3/TOC text panels render without cutoff in target test resolution.
- Audit logs show no persistent `CONSOLE_LAYOUT_AUDIT_FAIL` for the tested flow.
