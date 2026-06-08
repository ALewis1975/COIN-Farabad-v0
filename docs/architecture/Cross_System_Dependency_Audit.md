# Farabad COIN v0 - Cross-System Dependency Audit

**Version:** 1.0  
**Date:** 2026-06-08  
**Status:** Active architecture audit  
**Mode:** F - Documentation-Only Changes  
**Parent contracts:** `docs/architecture/Farabad_Ecosystem_Architecture_v1.md`, `docs/architecture/Layer_Contract_Ledger.md`, `docs/architecture/State_Config_Ownership_Overlay.md`  
**Scope:** Audit framework and initial dependency-risk board for cross-system reads, upward dependencies, UI authority leakage, and implicit policy ownership. No runtime behavior changes.

---

## 0) Truth status

This audit is a planning and review artifact. It classifies dependency risks that should be checked before behavior-changing work expands cross-system integration.

Truth classification:

| Claim type | Status |
|---|---|
| Ecosystem dependency rules from parent docs | Branch-local until parent PR stack merges |
| Runtime bug claims | None in this document |
| Code-path findings | Audit targets only unless marked `confirmed` in a later update |

This document does not assert that a listed target is currently broken. It defines where reviewers must look before approving refactors or features that cross ecosystem layers.

---

## 1) Purpose

Farabad COIN now has layer contracts for terrain, time, population, governance, OPFOR, BLUFOR, threat, intel, operations, sustainment, and interface. The next failure mode to prevent is hidden coupling: a system reads another subsystem's internal state, infers missing facts, or uses a higher gameplay layer as a foundation-layer policy source.

This audit creates a bounded review board for:

- Direct cross-subsystem reads.
- Upward dependencies from foundation layers into gameplay layers.
- UI reads of internal state or UI-local mutation of authoritative state.
- Scheduler coupling that bypasses runtime budget policy.
- Time, terrain, and persistence facts computed independently by consumers instead of resolved through owner layers.

---

## 2) Dependency categories

| Category | Meaning | Required outcome |
|---|---|---|
| `OK_CONTRACTED` | Cross-layer dependency uses a public snapshot, delta bundle, or validated service path. | Keep, document consumer. |
| `LEGACY_ACCEPTED` | Direct read exists but is stable and bounded during migration. | Track migration owner/date or justify retaining. |
| `NEEDS_ADAPTER` | Consumer reads internal state that should be exposed through adapter or snapshot. | Add adapter/snapshot task before behavior expands. |
| `UPWARD_DEPENDENCY` | Lower/foundation layer depends on higher gameplay layer for canonical policy. | Invert ownership or define compatibility mirror. |
| `UI_AUTHORITY_RISK` | UI may infer or mutate authoritative gameplay state. | Route through Console VM/request handler. |
| `RUNTIME_BUDGET_RISK` | Scheduler or physical ambience path does not clearly consume runtime policy or cap discipline. | Add L0 review before new behavior. |
| `BLOCKED_RUNTIME` | Static contract exists, but behavior cannot be trusted until hosted/dedicated/JIP evidence exists. | Add `tests/TEST-LOG.md` obligation. |

---

## 3) Initial audit board

| ID | Area | Suspected dependency | Category | Owner | Required next action |
|---|---|---|---|---|---|
| DEP-001 | Time / CIVSUB | Dynamic TOD currently mirrors or derives activity windows from CIVSUB-facing activity config. | `UPWARD_DEPENDENCY` | Core / CIVSUB | Define Time / Tempo Policy contract and compatibility wrapper before code refactor. |
| DEP-002 | UI tabs | Some console tabs still read legacy `missionNamespace` values instead of normalized Console VM sections. | `UI_AUTHORITY_RISK` / `NEEDS_ADAPTER` | UI / Console VM | Maintain tab-by-tab source map. Move direct reads through VM or documented `ARC_pub_*` snapshots by parity. |
| DEP-003 | Threat scheduler | Threat pressure consumes district posture and scheduler state; runtime budget integration needs explicit contract before new pressure logic. | `RUNTIME_BUDGET_RISK` | Threat / Core | Run Threat reliability sweep before adaptive behavior changes; review L0 runtime policy before new scheduler logic. |
| DEP-004 | World terrain consumers | Multiple systems consume terrain/site/marker facts; World Registry should be the spatial owner. | `NEEDS_ADAPTER` | World | Define World Registry contract and identify consumers before more terrain-derived behavior. |
| DEP-005 | BLUFOR readiness | Readiness exists across S1, company command, medical, logistics, airbase, and task state. | `NEEDS_ADAPTER` | Core / Command / Logistics / Medical | Define BLUFOR readiness read model before broad S3 follow-on policy changes. |
| DEP-006 | Sustainment and S3 follow-on | S3 follow-on recommendations should consume sustainment constraints explicitly. | `NEEDS_ADAPTER` | TASKENG / Logistics / Medical | Define Sustainment / S4 readiness snapshot before adding S3 policy hints. |
| DEP-007 | Government / GREEN | GREEN legitimacy exists in CIVSUB, but government agency behavior is not yet a narrow runtime contract. | `LEGACY_ACCEPTED` | CIVSUB / future Gov bridge | Write Government Layer planning spec before persistent government state or scheduler. |
| DEP-008 | OPFOR capacity | Threat currently carries pressure that may later belong to OPFOR network capacity. | `LEGACY_ACCEPTED` | Threat / future OPFOR bridge | Write OPFOR Network planning spec before persistent hidden network state. |
| DEP-009 | SitePop / Prison | Site presence uses world anchors and may later interact with government/prison handoff semantics. | `NEEDS_ADAPTER` | SitePop / Prison / World | Keep server-mediated handoff behavior and document world-anchor consumers. |
| DEP-010 | Public snapshots | Public snapshots can grow into unbounded mirrors if used as integration shortcuts. | `OK_CONTRACTED` with risk | Core | Keep snapshots bounded and presentation-oriented. Reject mirror-style expansion. |

---

## 4) Review checklist by PR type

### 4.1 Documentation PRs

- [ ] Does the doc assign ecosystem layer ownership correctly?
- [ ] Does it avoid claiming runtime behavior without evidence?
- [ ] Does it preserve the active architecture plan and pre-dedicated completion ledger as authorities?
- [ ] Does it avoid creating a parallel roadmap?

### 4.2 Safe refactor PRs

- [ ] Does the refactor preserve behavior parity?
- [ ] Does it remove or reduce a direct internal read?
- [ ] Does it avoid changing public interfaces unless declared?
- [ ] Does it update State/Config Overlay if ownership changes?
- [ ] Does it keep lower layers from depending on higher gameplay layers?

### 4.3 Feature PRs

- [ ] Does the feature declare producer and consumer layers?
- [ ] Does state flow through snapshot, delta bundle, or validated request path?
- [ ] Does the feature need RemoteExec S0-S5 audit updates?
- [ ] Does the feature add scheduler or physical ambience pressure that requires L0 review?
- [ ] Does the feature create dedicated/JIP test obligations?

### 4.4 UI PRs

- [ ] Does the UI read from Console VM or documented `ARC_pub_*` state?
- [ ] Does the UI show stale/unknown/denied state instead of clearing to false no-data?
- [ ] Does every action route through client request -> server validation -> snapshot refresh?
- [ ] Does any UI-local state remain local and non-authoritative?

---

## 5) Direct-read migration pattern

Use this order when replacing a direct internal read:

1. Identify the producer layer and subsystem owner.
2. Confirm the key-level writer in `State_Ownership_Ledger.md` when replicated state is involved.
3. Decide whether the consumer needs a public snapshot, VM section, or service function.
4. Add the adapter/snapshot in a Mode C or Mode B PR, depending on behavior impact.
5. Keep legacy read fallback only while parity is tested.
6. Remove legacy read in a separate parity-backed Mode C PR.
7. Record hosted/dedicated/JIP obligations when UI or public state behavior changes.

---

## 6) Upward dependency remediation pattern

Use this order when a lower layer depends on a higher layer for policy:

1. Name the policy that must move downward.
2. Assign canonical ownership to the lower/foundation layer.
3. Keep compatibility mirrors in the higher layer only if needed.
4. Update docs before code.
5. Add wrapper/read model with behavior parity.
6. Convert one consumer at a time.
7. Remove higher-layer canonical ownership only after runtime proof.

Current primary target: Time / Tempo Policy should own canonical phase/window logic; CIVSUB, Threat, Airbase, and Ops should consume it.

---

## 7) Runtime-budget review pattern

Any new scheduler or physical ambience expansion must answer:

- [ ] Which layer owns the behavior?
- [ ] Which layer owns the runtime cap or budget?
- [ ] What happens under safe mode or degraded mode?
- [ ] What is the cleanup path?
- [ ] What is the JIP/reconnect behavior?
- [ ] Does this affect dedicated-server validation scope?

If no runtime budget exists, default to conservative behavior and define the L0 Runtime Boundary contract before implementation.

---

## 8) Closure criteria

This audit is useful when:

1. Every cross-layer implementation PR cites a dependency category or adds one.
2. Every direct internal read has a migration decision: keep, adapter, snapshot, or service path.
3. Every upward dependency has an ownership inversion plan or an explicit compatibility exception.
4. Every new scheduler or physical ambience path has L0 runtime-budget review.
5. Every UI action proves it is request-driven and server-validated.
6. Runtime claims are reflected in `tests/TEST-LOG.md`, not inferred from static review.

---

## 9) Relationship to active documents

| Document | Relationship |
|---|---|
| `docs/architecture/Farabad_Ecosystem_Architecture_v1.md` | Defines dependency direction and layer model. |
| `docs/architecture/Layer_Contract_Ledger.md` | Defines the layer rows this audit references. |
| `docs/architecture/State_Config_Ownership_Overlay.md` | Defines state/config layer ownership used by this audit. |
| `docs/architecture/State_Ownership_Ledger.md` | Remains key-level writer authority. |
| `docs/architecture/Configuration_Ownership_Ledger.md` | Remains config classification authority. |
| `docs/architecture/Console_VM_v1.md` | Primary UI consumption pattern for Interface layer. |
| `docs/security/RemoteExec_Endpoint_Audit_Matrix.md` | Required when dependency changes affect request surfaces. |
| `docs/qa/Pre_Dedicated_Mission_Completion_Audit_2026-04-06.md` | Runtime-readiness claims remain subordinate to this completion ledger. |

---

## 10) Update policy

Update this audit when:

- A direct cross-subsystem read is found, accepted, migrated, or removed.
- A lower layer depends on a higher layer for policy.
- A new UI action consumes or mutates state.
- A scheduler or physical ambience path changes runtime pressure.
- A layer owner changes in the State/Config Overlay.
- Runtime validation closes or reopens a dependency risk.
