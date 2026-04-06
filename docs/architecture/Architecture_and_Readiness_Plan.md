# Farabad COIN v0 — Architecture Assessment & Readiness Plan (Revised)

**Version:** 2.0  
**Date:** 2026-04-04  
**Assessment Baseline:** **B-**  
**Reason for revision:** Fact correction quality was acceptable, but response hygiene and scope control were inconsistent with requested deliverable shape.

---

## 1) Executive assessment (revised)

The project architecture is structurally strong and coherent:

- **Authority model is sound and explicit.**
  - Server is the single writer for persistent/shared state (`ARC_STATE`, `ARC_pub_state` publish path).
  - Clients are snapshot consumers and requesters, not authoritative mutators.
- **Entry-point design is coherent.**
  - `initServer.sqf` establishes operational toggles and server posture before bootstrap flow.
  - `initPlayerLocal.sqf` applies readiness gating and fallback refresh behavior for client initialization.
- **Subsystem modularity is strong.**
  - `config/CfgFunctions.hpp` maintains explicit domain grouping (core/world/threat/ied/civsub/ui/ambiance/logistics/medical/sitepop, etc.).

The primary near-term risks are **governance/operational discipline**, not core architecture:

1. **Branch drift risk:** local conclusions can become stale when not verified against `origin/main`.
2. **RPC surface risk:** wide RemoteExec endpoint surface requires sustained allowlist + sender/authz enforcement.
3. **Validation imbalance risk:** static checks are mature; dedicated/JIP runtime evidence remains weaker.
4. **Complexity coupling risk:** airbase/taskeng/sitepop cross-system behaviors are regression-prone without explicit audit tracks.

---

## 2) What changed in this revision

This revision updates assessment governance and readiness criteria:

- Reframes grade baseline to **B-** and clarifies why.
- Moves risk emphasis from structural concerns to execution/governance discipline.
- Adds a mandatory **truth-before-claim** evidence gate for diagnostic/assessment work.
- Aligns readiness with explicit closure of dedicated/JIP deferred validation obligations.
- Removes PR-template-style output assumptions from assessment tasks unless explicitly requested.

---

## 3) Architecture integrity anchors (confirmed)

### 3.1 Authority and ownership

- Server-authoritative single-writer model remains the non-negotiable contract.
- Shared mission state writes must remain server-side and explicit.
- Client UI/state handling must remain non-authoritative and snapshot-driven.

### 3.2 Bootstrap and lifecycle coherence

- Server bootstrap ordering (configuration before subsystem init) remains correct.
- Client gating/watcher logic remains appropriate for JIP and delayed snapshot availability.

### 3.3 Subsystem partitioning

- Function registry and file layout continue to support modular ownership and targeted audits.
- No revision required to subsystem boundaries at this stage.

---

## 4) Revised risk model

### P1 — Governance/source-of-truth drift
- Impact: incorrect diagnostics, wasted iteration, conflicting remediation.
- Mitigation: enforce branch-truth checks before assertions.

### P1 — RemoteExec hardening debt
- Impact: avoidable security and integrity exposure.
- Mitigation: endpoint-by-endpoint verification against hardening matrix.

### P1 — Runtime evidence gap (dedicated/JIP)
- Impact: integration regressions can pass static gates undetected.
- Mitigation: explicit deferred-check closure requirements, not implicit backlog.

### P2 — Cross-subsystem coupling regressions
- Impact: nuanced failures in airbase/taskeng/sitepop/civsub interactions.
- Mitigation: dedicated reliability tracks with focused acceptance criteria.

---

## 5) Readiness posture (revised)

**Overall:** CONDITIONAL GO for continued implementation, conditioned on process hardening:

Required for “healthy readiness”:
- Truth-before-claim branch verification on every diagnostic task.
- RemoteExec/security track completion and periodic re-audit.
- Runtime validation closure for dedicated/JIP checks tied to changed gameplay paths.
- Continued use of compat + sqflint preflight and test-log evidence discipline.

---

## 6) Mandatory process controls (effective immediately)

1. **Truth-before-claim gate (required):**
   - Compare relevant local artifact(s) with `origin/main` before asserting current reality.
2. **Branch-drift check step (required):**
   - Explicitly record whether finding is branch-local or `main`-confirmed.
3. **Scope/format discipline (required):**
   - For analysis requests, provide analysis only (no PR-format output unless requested).
4. **Evidence discipline (required):**
   - Distinguish static validation from runtime validation; do not conflate.

---

## 7) Forward execution linkage

Execution details are now canonicalized in:

- `/home/runner/work/COIN-Farabad-v0/COIN-Farabad-v0/docs/planning/Task_Decomposition.md`
- `/home/runner/work/COIN-Farabad-v0/COIN-Farabad-v0/docs/qa/Pre_Dedicated_Mission_Completion_Audit_2026-04-06.md`

This architecture assessment defines the risk model and controls; the decomposition document defines implementation order and work packages.
The pre-dedicated completion audit is the canonical subsystem-by-subsystem ledger for deciding whether the mission is feature-complete enough to spend dedicated/JIP time and money.
