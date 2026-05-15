# Farabad COIN v0 — Architecture Plan

**Version:** 1.2
**Date:** 2026-05-08
**Status:** Active architecture plan (current-clone analysis; not yet main-confirmed)
**Mode:** F — Documentation-Only Changes
**Scope:** Forward-looking architecture plan and roadmap. Does not redesign existing systems; consolidates and supersedes the planning portions of `Architecture_and_Readiness_Plan.md` while keeping that file as historical assessment context.

---

## 0) Truth-status disclaimer

This plan was authored from the current cloned working branch. Per `docs/projectFiles/Farabad_Source_of_Truth_and_Workflow_Spec.md`, every diagnostic conclusion must be marked as **branch-local** until verified against `origin/main`.

- **Branch-local at authoring time:** all assessment statements in §1.
- **Main-confirmed:** none yet. Phase 0 closes this gap.

Do not treat this document as release truth until §6 (Phase 0) is complete.

---

## 1) Current-state assessment

### 1.1 Architecture posture

The repository is structurally coherent and should continue from the existing server-authoritative architecture rather than being redesigned.

Core anchors:

- Server bootstrap/config: `initServer.sqf`
- Client bootstrap/watchers: `initPlayerLocal.sqf`
- Function registry: `config/CfgFunctions.hpp`
- RemoteExec allowlist: `config/CfgRemoteExec.hpp`
- Prior readiness plan: `docs/architecture/Architecture_and_Readiness_Plan.md`
- Canonical execution board: `docs/qa/Pre_Dedicated_Mission_Completion_Audit_2026-04-06.md`

### 1.2 Strengths (carry forward)

- Server-as-single-writer model is consistently documented and reflected in core state functions.
- Client initialization is gated on server readiness and public snapshot availability.
- `CfgRemoteExec` is whitelist-only and grouped by client→server, server→client, and JIP-critical endpoints.
- Subsystems are well partitioned: core, world, CIVSUB, TASKENG/SITREP, command, UI, airbase, threat, IED, logistics, medical, sitepop, prison.
- Existing docs already identify the main development risk correctly: not missing architecture, but runtime evidence gaps and governance drift.

### 1.3 Main risks

| # | Risk | Why it matters |
|---|---|---|
| R1 | **Source-of-truth drift** | Several older QA docs contain findings later marked superseded; current-clone findings must be verified against `origin/main` before being treated as truth. |
| R2 | **Runtime validation gap** | Many systems are classified `runtime-only unverified`; dedicated/JIP, reconnect, respawn, persistence durability, and mod-stack validation remain release-critical unknowns. |
| R3 | **RemoteExec / security surface** | The allowlist is much improved, but the number of client→server endpoints remains large; the hardening plan needs to become an endpoint-by-endpoint audit ledger, not just a policy doc. |
| R4 | **Console / UI complexity** | The Farabad Console has grown into a shared platform, but many tabs still rely on direct `missionNamespace` reads and tab-specific layout/painter logic; the Console VM pattern is only partially adopted. |
| R5 | **Configuration concentration** | `initServer.sqf` holds many subsystem flags, tuning values, class pools, and operator toggles; continued growth without ownership clarification raises regression risk. |

---

## 2) Target architecture

### 2.1 Authority and state layer

Keep the existing model:

- Server owns authoritative state.
- Clients submit requests only.
- Clients render from published snapshots.
- Persistent state remains versioned and migratable.

Refine the state layer into **three explicit categories**:

| Category | Storage | Writer | Replicated? | Purpose |
|---|---|---|---|---|
| Authoritative persistent state | `ARC_state` via `ARC_fnc_stateGet` / `ARC_fnc_stateSet` | Server only | No (internal) | Schema-versioned source of truth; saved/restored through profile persistence. |
| Published public snapshots | `ARC_pub_*` mission variables | Server only | Yes (`publicVariable true`) | Bounded, presentation-oriented, JIP-safe consumer feed. |
| Client UI state | `uiNamespace` and `private` locals | Client only | Never | Selections, tabs, filters, refresh state. Never authoritative. |

Hard rule: no subsystem outside Core writes to `ARC_state` or `ARC_pub_*` directly. All authoritative writes go through `ARC_fnc_stateSet`; all public publishes go through `ARC_fnc_publicBroadcastState` or a designated `ARC_fnc_*Broadcast` function for that subsystem.

### 2.2 Integration / event layer

Use **delta bundles** as the cross-system integration bus.

| Producers | Consumers |
|---|---|
| TASKENG / SITREP | Public snapshot publisher |
| CIVSUB | Console VM |
| Threat / IED / VBIED | Intel / lead generation |
| Airbase / CASREQ | Mission scoring |
| Medical / CASEVAC | Runtime diagnostics |
| Logistics / Convoy | |

Rule: subsystems exchange **bounded event envelopes**, not direct reads into each other’s internal state. Each envelope carries event identity, timestamp, actor + target context, payload, optional influence deltas, and optional lead/task hints (as already specified in the Mission Design Guide §4.3).

### 2.3 RPC / security layer

Treat RemoteExec as a security boundary. For every client→server endpoint, record status for:

- **S0** — server guard (`if (!isServer) exitWith {};`)
- **S1** — sender / object binding (`ARC_fnc_rpcValidateSender` or equivalent)
- **S2** — parameter type / shape validation
- **S3** — role authorization
- **S4** — world / state invariant checks
- **S5** — idempotency / rate-limit + structured security logging

`docs/security/RemoteExec_Hardening_Plan.md` policy + `docs/security/RemoteExec_Endpoint_Audit_Matrix.md` ledger together form the live security surface tracker.

### 2.4 UI / Console layer

Move toward a console **platform architecture**:

- Shared shell owns layout regions.
- Tabs declare layout needs.
- Painters render from normalized VM sections.
- Buttons route through tab-aware action dispatch.
- Debug telemetry is separated from default operator views.
- AIR/TOWER remains the proving ground; the model must apply to all tabs over time.

Canonical references:

- `docs/architecture/Farabad_Console_Refactor_Plan.md`
- `docs/architecture/Console_VM_v1.md`
- `docs/planning/Console_Tab_Migration_Plan.md`

### 2.5 Subsystem boundaries (ownership)

| Subsystem | Owns |
|---|---|
| **Core** | State, persistence, logging, roles, bootstrap, public snapshot publishing. |
| **TASKENG / SITREP / Command** | Mission cycle: task / lead / order / SITREP state machines. |
| **CIVSUB** | District influence, identity, civilian sampling, civilian interactions. |
| **Threat / IED / VBIED** | Insurgent risk, threat records, attack lifecycle, evidence / disposition. |
| **Airbase / CASREQ** | Airfield ambience, clearances, runway / queue lifecycle, CAS request workflow. |
| **World / SitePop / Prison** | World anchors, dynamic site population, named-location NPC presence. |
| **UI** | Rendering only; never authoritative mutation. |
| **Logistics / Medical** | Sustainment, convoys, casualties, CASEVAC integration. |

Cross-boundary interaction is event-driven (delta bundles) and read-only against published snapshots.

---

## 3) Configuration ownership policy (R5 mitigation)

To prevent `initServer.sqf` from becoming a single point of regression risk, classify every operator-visible variable into one of:

| Class | Examples | Where it should live |
|---|---|---|
| Mission posture toggle | `ARC_safeModeEnabled`, `ARC_profile_devMode`, `civsub_v1_enabled` | `initServer.sqf` (kept; surfaced through startup audit). |
| Subsystem tuning constant | radius / cooldown / cap / interval values | `data/ARC_ConfigData.sqf` (preferred) or subsystem-owned init function. |
| Class pool / classname registry | IED / VBIED / civ / patrol pools | `data/ARC_ConfigData.sqf` or subsystem `*Init` builders. |
| Runtime-derived state | `ARC_pub_*`, derived caches (`ARC_bridgeMarkers`, etc.) | Computed by core / subsystem init at bootstrap; not authored as a constant. |

Rule: when adding a new operator toggle, also add a startup-audit entry (see `ARC_fnc_operatorToggleAuditStartup`) so RPT operators can confirm it took effect. No silent toggles.

---

## 4) Acceptance criteria for "architecturally healthy"

The mission should be considered architecturally healthy when **all** of the following are simultaneously true:

1. Every replicated `missionNamespace` key has a documented single writer.
2. Every client→server RPC has S0–S5 ledger status; no privileged RPC lacks S1 + role check.
3. Every persisted store has schema version + reset + migration test coverage (`scripts/dev/validate_state_migrations.py`).
4. Every console tab reads from either Console VM or a documented `ARC_pub_*` snapshot, with explicit empty-state handling.
5. Every subsystem can complete its lifecycle loop without unhandled fallback in a representative scenario, with structured logs at critical transitions.
6. Dedicated/JIP, reconnect, and respawn behaviors are evidenced in `tests/TEST-LOG.md` against current head, not stale runs.

---

## 5) Non-goals (this plan)

- Do **not** redesign the authority model.
- Do **not** redesign persistence schema.
- Do **not** rewrite core state functions or `publicBroadcastState`.
- Do **not** introduce a new dialog class or replace the Farabad Console shell.
- Do **not** add new RemoteExec endpoints during the hardening phase.

If a workstream appears to require any of the above, stop and update this plan via a versioned bump before implementation.

---

## 6) Development roadmap

### Phase 0 — Truth alignment and documentation hygiene

**Goal:** eliminate stale planning as an active risk.

Actions:

- Mark current-clone vs main-confirmed evidence in all future architecture / QA docs.
- Treat `docs/qa/Pre_Dedicated_Mission_Completion_Audit_2026-04-06.md` as **the** completion ledger; supersede competing "what's left?" narratives.
- Move superseded QA findings out of active planning unless freshly reproduced on current head.
- Cross-link active plans from `README.md`, `Architecture_and_Readiness_Plan.md`, and the completion audit.

Acceptance:

- One canonical "what remains before dedicated/JIP" board.
- Older findings clearly marked superseded or current.
- No planning doc drives work without current-source evidence.

### Phase 1 — Security and authority hardening

**Goal:** close the highest-risk architecture surface before more feature work.

Actions:

- Convert `docs/security/RemoteExec_Hardening_Plan.md` policy into the live audit ledger maintained at `docs/security/RemoteExec_Endpoint_Audit_Matrix.md`.
- Verify all client→server RPCs against S0–S5 checks; record status per endpoint.
- Minimize command-class allowlist usage where named wrappers are feasible.
- Confirm all JIP-enabled RPCs are persistent, object-bound, and idempotent.

Acceptance:

- No privileged RPC lacks sender binding and role / invariant checks.
- JIP allowlist remains narrow.
- Security logging is consistent (`[ARC][SEC]` prefix; structured fields).

### Phase 2 — State, persistence, and snapshot stabilization

**Goal:** make state behavior boring before runtime validation.

Actions:

- Re-audit state schema migrations and reset / rebuild flows.
- Verify bounded stores for logs, queues, histories, metrics, and public snapshots (caps + TTL where appropriate).
- Clarify ownership for every replicated `missionNamespace` key (single-writer table).
- Keep public snapshots presentation-oriented; reject changes that expand them into unbounded mirrors of internal state.

Acceptance:

- Re-running migrations is a no-op when appropriate.
- Reset / rebuild paths leave no orphaned active tasks, orders, records, or spawned entities.
- JIP clients reconstruct UI from snapshots without hidden assumptions.

### Phase 3 — Console platform migration

**Goal:** reduce UI regression risk.

Actions:

- Finish Console VM migration tab-by-tab using `Console_Tab_Migration_Plan.md` as the worklist.
- Introduce declared layout regions for all console tabs (per `Farabad_Console_Refactor_Plan.md`).
- Keep AIR/TOWER as first full proving ground.
- Move direct tab reads toward normalized VM adapters.
- Separate operator, commander, pilot, and debug views.

Acceptance:

- Each tab has explicit data source, freshness signal, empty state, and action permissions.
- No tab-specific layout hack breaks another tab.
- Console actions remain client request → server validation → snapshot refresh.

### Phase 4 — Subsystem reliability sweeps

**Goal:** prove lifecycle loops in representative scenarios.

Execution detail for the Phase 4 sweep and the follow-on adaptive COIN behavior track is captured in `docs/planning/Subsystem_Reliability_and_Adaptive_COIN_Plan.md`.

Priority order:

1. AIRBASE / CASREQ
2. SitePop / Prison
3. CIVSUB / Threat / IED
4. TASKENG / SITREP / follow-on orders
5. Logistics / Medical / World ambience

Acceptance:

- Each subsystem has a smoke checklist.
- Fallback behavior is logged.
- Known mod-stack dependencies are documented in `README.md`.
- Runtime failures become bounded single-mode tasks per `AGENTS.md`.

### Phase 5 — Dedicated / JIP release-candidate gate

**Goal:** spend dedicated-server time only after static / code / content blockers are closed.

Required validation:

- Dedicated server fresh start.
- Persistence save / load across restart.
- JIP late-join after active task / order / airbase state exists.
- Reconnect and respawn.
- Public snapshot recovery.
- RemoteExec security rejection tests.
- Full mod-stack RPT review.

Acceptance:

- `tests/TEST-LOG.md` has PASS / FAIL / BLOCKED evidence per check, against current head.
- No release claim is based only on static validation.
- Any failed runtime check becomes a scoped follow-up task.

---

## 7) Recommended immediate next actions

1. Main-confirm this current-clone assessment before treating it as release truth.
2. Update the active completion ledger (`docs/qa/Pre_Dedicated_Mission_Completion_Audit_2026-04-06.md`) rather than creating another parallel plan.
3. Run the RemoteExec endpoint audit (Phase 1) as the first hardening workstream against `docs/security/RemoteExec_Endpoint_Audit_Matrix.md`.
4. Freeze broad feature work until the runtime-only-unverified board is reduced.
5. Continue AIR/TOWER and Console VM migration, but keep it isolated from backend rewrites.
6. Prepare a dedicated/JIP validation matrix from current-head evidence only.

---

## 8) Document relationships

| Document | Role relative to this plan |
|---|---|
| `docs/architecture/Architecture_and_Readiness_Plan.md` | Historical assessment baseline (B-) and governance framing. Still relevant for §1 context; this plan is the active forward roadmap. |
| `docs/qa/Pre_Dedicated_Mission_Completion_Audit_2026-04-06.md` | Canonical subsystem completion ledger. Phases 4–5 close items off this board. |
| `docs/planning/Task_Decomposition.md` | Workstream / track decomposition. Phases here map to its tracks 1–7. |
| `docs/planning/Subsystem_Reliability_and_Adaptive_COIN_Plan.md` | Phase 4 reliability-sweep execution contract plus the follow-on adaptive enemy/population behavior track. |
| `docs/security/RemoteExec_Hardening_Plan.md` | Policy definition for the RPC surface. |
| `docs/security/RemoteExec_Endpoint_Audit_Matrix.md` | Phase 1 live audit ledger derived from the hardening plan. |
| `docs/architecture/State_Ownership_Ledger.md` | Phase 2 single-writer ledger for replicated `ARC_pub_*` keys and subsystem-runtime replicated state. |
| `docs/architecture/Configuration_Ownership_Ledger.md` | Wave 7-T1 classification of every operator-visible variable in `initServer.sqf` (R5 mitigation per §3). |
| `docs/qa/Dedicated_JIP_Validation_Matrix.md` | Phase 5 release-candidate smoke checklist (dedicated/JIP/persistence/recovery). |
| `docs/architecture/Farabad_Console_Refactor_Plan.md` + `Console_VM_v1.md` + `docs/planning/Console_Tab_Migration_Plan.md` | Phase 3 implementation references. |
| `docs/projectFiles/Farabad_COIN_Mission_Design_Guide_v0.4_2026-01-27.md` | Mission intent and cross-cutting standards. Architectural changes must remain consistent with this guide unless it is version-bumped. |
| `docs/projectFiles/Farabad_Source_of_Truth_and_Workflow_Spec.md` | Branch-truth and workflow governance. Phase 0 discipline lives here. |

---

## 9) Update policy

This plan is updated when any of the following changes:

- The phase order, scope, or acceptance criteria of any phase.
- The set of subsystem boundaries or ownership rules.
- The hard non-goals in §5.

Process:

1. Open a Mode F PR.
2. Bump the version + date at the top.
3. Note the change in a short change-log section appended to this document.
4. Update cross-references in `README.md` and `Architecture_and_Readiness_Plan.md` if the plan is renamed or replaced.

---

## Change log

### v1.3 — 2026-05-08
- Wave 3-T2 deliverable landed (next-wave Mode F batch continuation):
  - `docs/security/RemoteExec_Endpoint_Audit_Matrix.md` v1.3 — completed audit batch 3 for CASREQ/Airbase + Logistics/Medical/CASEVAC endpoint set.
  - §3.5 S4/S5 statuses for all Airbase/TOWER client→server endpoints are now explicit.
  - New §3.6 endpoint group added for CASREQ + Logistics/Medical/CASEVAC with four new findings (F-AIR-1, F-CAS-1, F-LOG-1, F-MED-1).
- No phase / scope / non-goal changes.

### v1.4 — 2026-05-14
- Added `docs/planning/Subsystem_Reliability_and_Adaptive_COIN_Plan.md` as the Phase 4 execution contract for subsystem reliability sweeps and the follow-on adaptive COIN behavior track.
- No phase / scope / non-goal changes.

### v1.2 — 2026-05-08
- Wave 3-T1 / Wave 4-T1 / Wave 7-T1 deliverables landed (next-wave Mode F batch):
  - `docs/security/RemoteExec_Endpoint_Audit_Matrix.md` v1.2 — §3.3 Objective / IED / VBIED endpoints audited (S0–S5). Three new findings (F-IED-1..3).
  - `docs/architecture/State_Ownership_Ledger.md` v1.1 — extended with §3.10 (S1 registry) and §3a (subsystem-runtime replicated state for `airbase_v1_*`, `civsub_v1_*`, `casreq_v1_*`). Three new findings (S-OWN-4..6).
  - `docs/architecture/Configuration_Ownership_Ledger.md` v1.0 — new doc; classifies all 242 operator-visible variables in `initServer.sqf` per §3. Four open findings (C-OWN-1..4) seeding Wave 7-T2 / W7-T3.
- Cross-references in §8 updated to point at the Configuration Ownership Ledger.
- No phase / scope / non-goal changes.

### v1.1 — 2026-05-08
- Added cross-references to two new Wave 2 / Wave 5 deliverables produced as part of "implement the plan" execution:
  - `docs/architecture/State_Ownership_Ledger.md` (Phase 2 single-writer ledger).
  - `docs/qa/Dedicated_JIP_Validation_Matrix.md` (Phase 5 release-candidate smoke checklist).
- No phase / scope / non-goal changes.

### v1.0 — 2026-05-08
- Initial issuance. Captures current-clone architecture posture, target architecture, ownership boundaries, configuration ownership policy, acceptance criteria, non-goals, and 6-phase roadmap (Phase 0 → Phase 5).
