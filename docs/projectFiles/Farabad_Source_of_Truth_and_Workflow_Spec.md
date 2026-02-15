# Farabad COIN — Source of Truth & Development Workflow Spec

**Status:** authoritative project workflow spec (v1.0)  
**Applies to:** `Farabad_COIN_v00.Farabad` (all systems)  
**Last updated:** 2026-02-14

---

## 1) Purpose

This file resolves two recurring governance gaps:

1. What is the project’s current **source-of-truth branch model**?
2. What is the **canonical workflow spec** for planning, patching, validation, and release gating?

It is written to be actionable for both human maintainers and AI-assisted contributors.

---

## 2) Canonical source-of-truth artifacts (document hierarchy)

Use this precedence when docs appear to conflict:

1. **This file** (`Farabad_Source_of_Truth_and_Workflow_Spec.md`) for branch/workflow governance.
2. **Mission Design Guide** for cross-system intent and project governance:  
   `docs/projectFiles/Farabad_COIN_Mission_Design_Guide_v0.4_2026-01-27.md`
3. **Subsystem locked baselines** for implementation contracts, e.g.:  
   - `docs/projectFiles/Farabad_TASKENG_SITREPSYS_v1_Baseline.md`  
   - `docs/projectFiles/Farabad_TASKENG_SITREPSYS_Snapshot_Baseline.md`  
   - other `*_Baseline*.md` docs in `docs/projectFiles/`
4. **Release gate checklist** for ship/no-ship decisions:  
   `docs/v00_release_readiness.md`
5. **Runbooks/playbooks** for execution hygiene and diagnostics:  
   - `docs/projectFiles/Farabad_Prompting_Integration_Playbook_Project_Standard.md`  
   - `docs/projectFiles/Farabad_Console_Regression_and_Git_Conflict_Runbook.md`

If conflict persists after applying this order, stop and open a governance clarification PR.

---

## 3) Branch source-of-truth model (project standard)

> This project did not include a reliably discoverable remote default branch policy in-repo.  
> The model below is now the project standard going forward.

### 3.1 Branch roles

- **`main`** = authoritative integration + release truth
  - Protected branch
  - Only merge via reviewed PRs
  - Must satisfy release and regression gates

- **`dev`** = active integration/staging branch
  - Feature work lands here first unless change is hotfix-critical
  - Must remain playable and dedicated-MP sane

- **`release/*`** (e.g. `release/v00`) = stabilization branch
  - Cut from `main` or `dev` when preparing a tag
  - Only bug fixes, validation, docs, and release hardening

- **`work/*` or short-lived feature branches**
  - Individual implementation branches
  - Never treated as source-of-truth

### 3.2 “Current source-of-truth branch” definition

For day-to-day project state, **`main` is source-of-truth**.

For release readiness status, source-of-truth is the pair:

- `main` (code truth), and
- `docs/v00_release_readiness.md` (ship gate truth)

Both must agree before tagging release.

---

## 4) Development workflow (mandatory)

### Phase A — Intake & contract anchor (no code)

1. Declare runtime context: dedicated MP, JIP requirements, server-authoritative constraints.
2. Name exact source docs being used (from Section 2 above).
3. Identify subsystem contract touched (owned keys, APIs, events, states).
4. Define acceptance checks before patching.

### Phase B — Minimal patch

1. Patch only required files.
2. Preserve existing authority model:
   - server is single writer
   - clients are requesters/renderers
3. Keep UI snapshot-driven (no client-side authoritative inference).
4. Avoid rewrites unless explicitly approved.

### Phase C — Verification

At minimum, verify:

- no merge markers / console conflict regressions
- remoteExec handlers used by clients are whitelisted
- lifecycle/state transitions remain contract-compliant
- dedicated MP + JIP expectations are not regressed

Use project scripts/checks where available (example: `scripts/dev/check_console_conflicts.sh`).

### Phase D — PR hygiene

Each PR must include:

- scope summary (what changed, what did not)
- authority/locality impact summary
- validation evidence (commands, logs, artifacts)
- explicit risk section + rollback note

---

## 5) Merge policy

- Prefer merge path: `work/*` -> `dev` -> `main`
- Hotfix path (rare): `work/*` -> `main` with explicit reason and follow-up back-merge into `dev`
- Do not bypass PR review for core systems (`core`, `taskeng`, `taskgen`, `sitrepsys`, `unitstat`, `ui/console`, `description.ext`, `CfgFunctions.hpp`)

---

## 6) Release policy

A release tag (e.g. `v00`) is allowed only when:

1. `docs/v00_release_readiness.md` is fully satisfied for the target scope.
2. Required dedicated MP/JIP artifacts are attached.
3. No known authority-model regressions remain open.
4. `main` contains the exact commit to be tagged.

---

## 7) Governance update policy

Update this file when any of the following changes:

- branch strategy (`main/dev/release/*` semantics)
- required validation gates
- document precedence hierarchy
- release gate process

Change process:

1. PR includes rationale and impacted docs list.
2. Update this file first, then dependent docs.
3. Note version/date bump in PR description.

---

## 8) Quick reference (operator checklist)

Before merging:

- [ ] Correct source docs identified
- [ ] Server-authoritative constraints preserved
- [ ] Client behavior remains snapshot-driven
- [ ] Minimal diff discipline followed
- [ ] Required static checks run
- [ ] Release checklist impact reviewed

