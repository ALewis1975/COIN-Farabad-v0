# Console Upgrade Merge Gates

This document defines mandatory merge gates for console-upgrade branches before PR approval and merge.

## 1) Required command list (exact command text)

Run commands in repository root unless otherwise noted.

### Git and merge-hygiene gates

1. `git fetch --all --prune`
2. `git rebase origin/main`
3. `git diff --check`
4. `rg -n "^(<<<<<<<|=======|>>>>>>>)" functions ui config initPlayerLocal.sqf initServer.sqf description.ext`
5. `git status --short`

### Console/runtime readiness gates

6. `[] execVM "dev\ARC_selfTest.sqf";`  *(Arma Debug Console command)*
7. `[true] execVM "dev\ARC_selfTest.sqf";`  *(Arma Debug Console command; verbose mode)*
8. `missionNamespace setVariable ["ARC_console_layout_audit", true];`  *(Arma Debug Console command; run before exercising console flow)*

### Runtime verification flow (must be executed after command #8)

9. Open console UI and execute the target regression scenario (task completion + SITREP submission).
10. Review RPT output for layout-audit and self-test results.

### PR metadata completeness gate

11. Verify PR description includes a `Scope of visible UI impact` section that explicitly lists:
   - visually affected tabs (for example: OPS-only), and
   - visually unchanged tabs (for example: DASH, CMD).
12. For each UI-related ticket, require **before/after verification evidence for each impacted tab only**.
13. For OPS-impacting tickets, require verification evidence captured from the **OPS tab** (DASH evidence is not accepted as substitute).
14. Verify PR description includes a tab-level verification table with columns:
   - `Tab`
   - `Expected visible change`
   - `Verification command/evidence`
   - `Reviewer sign-off`

15. Apply merge checklist item: **Reject PR if scope statement, impacted-tab before/after evidence, OPS-tab evidence rule, or verification table is missing/incomplete.**


## 2) Expected pass criteria per command

- `git fetch --all --prune`
  - Pass: exits with code 0 and updates refs without authentication or transport errors.
- `git rebase origin/main`
  - Pass: branch rebases cleanly with no unresolved conflicts and clean rebase state.
- `git diff --check`
  - Pass: no output (no whitespace errors, conflict leftovers, or malformed patch hunks).
- `rg -n "^(<<<<<<<|=======|>>>>>>>)" functions ui config initPlayerLocal.sqf initServer.sqf description.ext`
  - Pass: no matches.
- `git status --short`
  - Pass: only intended files are modified; no accidental scope expansion.
- `[] execVM "dev\\ARC_selfTest.sqf";`
  - Pass: RPT shows `[ARC][DEV]` self-test execution with no fatal script errors.
- `[true] execVM "dev\\ARC_selfTest.sqf";`
  - Pass: verbose self-test output confirms expected console invariants and no fatal script errors.
- `missionNamespace setVariable ["ARC_console_layout_audit", true];`
  - Pass: no script error; subsequent flow emits audit lines.
- Runtime verification flow
  - Pass: no persistent `CONSOLE_LAYOUT_AUDIT_FAIL`; no observed console overlap/cutoff regressions; SITREP path completes successfully.
- PR metadata completeness gate
  - Pass: PR description contains `Scope of visible UI impact` with both `Visually affected tabs` and `Visually unchanged tabs` explicitly listed.
  - Pass: each UI-related ticket includes before/after verification for every impacted tab and does not include unrelated tab evidence.
  - Pass: OPS-impacting tickets include OPS-tab evidence (DASH-only evidence fails this gate).
  - Pass: PR description includes a verification table with `Tab`, `Expected visible change`, `Verification command/evidence`, and `Reviewer sign-off`.
  - Fail: section is missing, uses placeholders, omits affected/unchanged tab scope declaration, lacks impacted-tab before/after evidence, uses non-OPS evidence for OPS-impacting changes, or omits required table columns.

## 3) Fail handling and escalation path

1. **Stop merge immediately** on any gate failure.
2. **Classify severity**:
   - **P0**: crash, data loss, broken build, or security-impacting behavior.
   - **P1**: incorrect console behavior/regression or unresolved merge conflict.
   - **P2**: maintainability/style issues with low regression risk.
3. **Create incident note** in PR comments with:
   - failing gate command,
   - exact output/error,
   - first bad commit (if known),
   - suspected file scope.
4. **Escalation chain**:
   - Primary: PR author
   - Secondary: console subsystem owner/reviewer
   - Tertiary: release manager/on-call mission maintainer
5. **Recovery actions**:
   - Re-run failed gate after targeted fix.
   - If rebase conflicts caused regression risk, perform hunk-level manual resolution and re-run all gates.
   - If unresolved within release window, revert/park branch and open follow-up hotfix ticket.

## 4) Mandatory sign-off roles

All roles below must explicitly approve before merge:

1. **PR Author** — confirms scope compliance and gate execution evidence.
2. **Console Code Owner/Subsystem Maintainer** — validates console behavior and conflict resolution quality.
3. **QA Verifier** — confirms runtime flow and audit-log pass criteria.
4. **Release Manager (or Duty Maintainer)** — final go/no-go based on risk and release timing.

No self-approval substitutions are allowed for Code Owner + QA on console-upgrade PRs.

## 5) Merge checklist (hard reject criteria)

- [ ] PR body includes `Scope of visible UI impact`.
- [ ] `Visually affected tabs` are explicitly listed (or `None`).
- [ ] `Visually unchanged tabs` are explicitly listed.
- [ ] Each UI-related ticket provides before/after verification for each impacted tab only.
- [ ] OPS-impacting tickets include OPS-tab verification evidence (not DASH-only evidence).
- [ ] PR body includes verification table with `Tab`, `Expected visible change`, `Verification command/evidence`, and `Reviewer sign-off`.
- [ ] Reviewer marks **Reject** if any item above is unchecked.
