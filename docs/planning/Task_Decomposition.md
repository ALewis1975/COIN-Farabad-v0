# Farabad COIN v0 — Task Decomposition (Revised)

**Version:** 2.0  
**Date:** 2026-04-04  
**Source:** Revised Architecture Assessment (`docs/architecture/Architecture_and_Readiness_Plan.md`)

**Canonical completion ledger:** `/home/runner/work/COIN-Farabad-v0/COIN-Farabad-v0/docs/qa/Pre_Dedicated_Mission_Completion_Audit_2026-04-06.md`

---

## 1) Objective

Execute the revised program of work with stronger governance discipline, explicit security/risk tracks, and clear runtime-validation closure criteria.

This decomposition supersedes older phase/task narratives that are now stale relative to current grading and workflow expectations.

---

## 2) Workstream decomposition (project-wide)

## Track 1 — Governance & Source-of-Truth Enforcement

### Scope
- Enforce `main`-truth checks for all architecture/diagnostic conclusions.
- Add mandatory branch-drift step in analysis workflow.
- Enforce response-shape discipline (analysis request → analysis output only).

### Deliverables
- Standardized truth-check procedure integrated into planning/analysis workflows.
- Explicit distinction between branch-local finding vs `main`-confirmed finding.

### Acceptance
- Every diagnostic artifact includes truth-check status.
- No informational request answered in PR-template format unless requested.

---

## Track 2 — Architecture Integrity

### Scope
- Re-verify single-writer boundaries for shared `missionNamespace` state.
- Audit client-only namespace usage (`uiNamespace`) to prevent authority leakage.
- Confirm subsystem ownership contracts remain aligned with locked baselines.

### Deliverables
- Updated architecture integrity audit notes with ownership confirmations/exceptions.

### Acceptance
- No unmediated client writes to authoritative shared mission state.
- Ownership boundaries documented and conflict-free.

---

## Track 3 — RemoteExec / Security

### Scope
- Validate each endpoint against hardening requirements:
  - sender binding
  - authorization gate
  - parameter type/shape validation
  - world/state invariants
  - rate-limit/idempotency behavior where needed
- Minimize risky command allowlist usage where wrappers are feasible.
- Re-confirm JIP persistence RPC set is narrow and intentional.

### Deliverables
- Endpoint validation matrix with pass/fail status and remediation list.

### Acceptance
- No unvalidated privileged client→server path remains in active surface.
- JIP usage restricted to persistent late-join requirements only.

---

## Track 4 — State / Persistence / TASKENG

### Scope
- Re-validate migration idempotency and backward compatibility.
- Verify bounded behavior and consistency of thread/task/lead stores across load/save cycles.
- Confirm reset/rebuild paths do not leave orphaned runtime state.

### Deliverables
- Persistence integrity report tied to schema revision rules.

### Acceptance
- Migration re-runs are no-op when appropriate.
- Reset/rebuild cycles produce consistent clean state.

---

## Track 5 — Runtime Subsystem Reliability

### Scope
- **Airbase:** queue lifecycle, crew seat assignment pathing, despawn marker logic, parked-restore continuity.
- **SitePop/Prison:** anchor resolution correctness, fallback log quality, spawn/despawn persistence coupling.
- **CIVSUB/Threat:** delta-bundle emission correctness and cross-system event hygiene.

### Deliverables
- Reliability checklists per subsystem with observed behavior and risk notes.

### Acceptance
- Critical lifecycle loops complete without stalls across representative scenarios.
- Fallback paths are explicit and logged.

---

## Track 6 — Validation & Evidence

### Scope
- Keep compat-scan + sqflint mandatory for changed SQF.
- Require local MP smoke checklist for changed gameplay paths.
- Treat dedicated/JIP checks as explicit gates with owner/date, not passive backlog.
- Keep `tests/TEST-LOG.md` current for every validation pass.

### Deliverables
- Validation records (PASS/FAIL/BLOCKED) with command/step evidence and context.

### Acceptance
- Every change has corresponding static validation evidence.
- Deferred runtime checks have explicit closure ownership.

---

## Track 7 — Execution Governance

### Scope
- Enforce the revised execution order and completion criteria.
- Prevent scope drift between tracks.

### Deliverables
- Ordered execution board tied to the four phases below.

### Acceptance
- Work proceeds in phase order unless an explicit risk-based exception is approved.

---

## 3) Execution order (mandatory)

## Phase 1 — Governance/Security Gates
- Track 1 (Governance & Source-of-Truth)
- Track 3 (RemoteExec/Security) initial pass

## Phase 2 — Persistence/Runtime Integrity Audits
- Track 2 (Architecture Integrity)
- Track 4 (State/Persistence/TASKENG)

## Phase 3 — Subsystem Regression Reliability Passes
- Track 5 (Airbase, SitePop/Prison, CIVSUB/Threat)

## Phase 4 — Dedicated/JIP Closure + Release Readiness
- Track 6 (Validation & Evidence) deferred closure
- Track 7 (Execution Governance) final readiness confirmation

---

## 4) Immediate grading-driven corrections (must apply now)

1. Add hard **truth-before-claim** checks to every diagnostic task.
2. Keep responses tightly scoped to user request type:
   - analysis request → analysis
   - plan request → plan
   - implementation request → implementation artifacts

---

## 5) Operational checklist (quick use)

- [ ] Verified relevant findings against `origin/main` before asserting.
- [ ] Marked each conclusion as branch-local or main-confirmed.
- [ ] Applied authority/ownership checks for affected subsystem.
- [ ] Applied RemoteExec/security checks for affected RPC surfaces.
- [ ] Ran required static validations for changed SQF/config.
- [ ] Logged validation results in `tests/TEST-LOG.md`.
- [ ] Recorded deferred dedicated/JIP checks with explicit owner/date.

---

## 6) Notes on scope control

- This document defines **what** to execute, not implementation-level code steps.
- Use subsystem baselines and security/QA guides as authoritative references during execution.
- Use the pre-dedicated completion audit as the canonical “complete vs missing” board before scheduling dedicated/JIP validation.
- If new requirements materially expand scope, update this decomposition before executing expanded work.
