# Farabad COIN v0 - State / Config Ownership Overlay

**Version:** 1.0  
**Date:** 2026-06-08  
**Status:** Active architecture overlay  
**Mode:** F - Documentation-Only Changes  
**Parent contracts:** `docs/architecture/Farabad_Ecosystem_Architecture_v1.md`, `docs/architecture/Layer_Contract_Ledger.md`  
**Canonical ledgers:** `docs/architecture/State_Ownership_Ledger.md`, `docs/architecture/Configuration_Ownership_Ledger.md`  
**Scope:** Ecosystem-layer ownership overlay for state and operator-visible configuration families. No runtime behavior changes.

---

## 0) Truth status

This overlay was authored from the ecosystem branch after PR #599 and PR #600 work, with `main` base commit lineage beginning at `ccfb7a1c59d9ade63d5fdf252445bff6d64df5a4`.

Truth classification:

| Claim type | Status |
|---|---|
| Existing state/config ledger purposes and file roles | Main-confirmed at the underlying architecture baseline |
| Ecosystem layer assignments introduced here | Branch-local until merged |
| Runtime behavior claims introduced here | None. This document changes planning and audit language only |

This overlay does not replace key-level writer records or config classification records. It adds the ecosystem-layer owner dimension so future code work does not create ambiguity between subsystem ownership and layer ownership.

---

## 1) Purpose

The State Ownership Ledger answers: **who writes this replicated state key?**

The Configuration Ownership Ledger answers: **what kind of operator-visible variable is this, and where should it live?**

This overlay answers: **which ecosystem layer owns the state or config family, and which layer may consume it?**

Use this overlay before implementation work when a PR touches any of the following:

- `ARC_state` or any `ARC_pub_*` public snapshot.
- A subsystem runtime state family such as `civsub_v1_*`, `threat_v0_*`, `airbase_v1_*`, or equivalent.
- An operator-visible variable in `initServer.sqf`, `data/ARC_ConfigData.sqf`, or subsystem init files.
- A new Console VM section or UI action that consumes published state.
- A new feedback loop that combines terrain, time, population, threat, intel, tasking, sustainment, or UI.

---

## 2) Authority model

| Ownership dimension | Canonical document | What it controls |
|---|---|---|
| Key-level writer | `docs/architecture/State_Ownership_Ledger.md` | Exact function(s) allowed to write replicated mission state. |
| Config classification | `docs/architecture/Configuration_Ownership_Ledger.md` | Whether a variable is posture toggle, tuning constant, class pool, or runtime-derived state. |
| Ecosystem layer owner | This overlay | Which layer owns the state/config family and which higher layers may consume it. |
| Layer contract | `docs/architecture/Layer_Contract_Ledger.md` | Layer authority, inputs, outputs, events, tests, failure mode, and next task. |

Hard rule: this overlay never authorizes a new writer. A state family still needs a documented server-side writer in `State_Ownership_Ledger.md` or a locked subsystem baseline.

---

## 3) State ownership overlay

| State family | Ecosystem layer owner(s) | Primary subsystem owner | Canonical state ledger | Allowed consumers | Overlay rule |
|---|---|---|---|---|---|
| `ARC_state` persistent source of truth | L3 State / Event / Persistence | Core | State Ownership Ledger + persistence docs | Server systems only | No client reads or writes. Public consumers use bounded snapshots. |
| `ARC_pub_state*` public campaign state | L3 State / Event / Persistence | Core | State Ownership Ledger | Console VM, dashboard, diagnostics | Presentation snapshot only. Do not expand into unbounded internal mirror. |
| `ARC_pub_orders*`, `ARC_pub_queue*` | L10 Operations / S3 | Command / TASKENG | State Ownership Ledger | Console VM, tasking UI, dashboard | Operations owns meaning. UI consumes only. |
| `ARC_pub_intelLog`, `ARC_pub_opsLog`, lead public stores | L9 Intel / S2 and L10 Operations / S3 | Core / Intel / TASKENG | State Ownership Ledger + TASKENG docs | Intel UI, tasking UI, dashboard, diary | Producer layer must be clear per event: intel product, ops log, or tasking artifact. |
| `ARC_pub_missionScore*` | L3 State / Event / Persistence with synthesis consumers | Core | State Ownership Ledger | Dashboard, diagnostics | Score is a derived read model. Do not use it as authoritative gameplay input unless separately specified. |
| `ARC_pub_casreqBundle*` | L8/L10 operational synthesis, CASREQ-owned | CASREQ / Airbase | State Ownership Ledger + CASREQ baseline | Air/Tower UI, pilots, TOC | CASREQ owns lifecycle. Interface consumes bundle and sends validated requests. |
| `ARC_pub_airbaseUiSnapshot*` | L7 BLUFOR Footprint and L12 Interface | Airbase / Core publisher | State Ownership Ledger | Tower/Air UI, dashboard | Airbase owns operational meaning. UI owns rendering only. |
| `ARC_pub_companyCommand*`, `ARC_pub_unitStatuses` | L7 BLUFOR Footprint and L10 Operations / S3 | Core / Command | State Ownership Ledger | Command UI, tasking UI, SITREP, dashboard | BLUFOR readiness and S3 task state must not drift. Follow-on logic consumes readiness explicitly. |
| `ARC_pub_s1_registry*` | L7 BLUFOR Footprint | Core / S1 | State Ownership Ledger | S1 UI, role helpers, command views | Personnel/unit registry is BLUFOR footprint data, not UI authority. |
| `ARC_pub_baseMed*` and medical public snapshots | L11 Sustainment / S4 | Medical | State Ownership Ledger | Medical UI, SITREP, tasking/follow-on recommendations | Sustainment owns readiness meaning. UI and S3 consume fresh-enough snapshot. |
| `ARC_pub_eodDispoApprovals*` | L8 Threat Synthesis and L11 Sustainment / S4 | IED / EOD | State Ownership Ledger | EOD actions, TOC, threat UI | Disposition approval is threat/evidence lifecycle state. UI cannot infer approval from local context. |
| `ARC_pub_debug*` | L3 State / Event / Persistence | Core / diagnostics | State Ownership Ledger | Debug operators only | Debug state never becomes gameplay authority. |
| `airbase_v1_*` runtime state | L7 BLUFOR Footprint, L8 operational synthesis, L12 Interface | Airbase | State Ownership Ledger section 3a / airbase docs | Tower UI, CASREQ, dashboard | Airbase owns queue/runway/clearance meaning. Other systems consume snapshots or APIs. |
| `civsub_v1_*` district, identity, traffic, locnpc, scheduler state | L4 Civilian / Population | CIVSUB | State Ownership Ledger section 3a / CIVSUB baseline | Threat, Intel, S3, UI, SITREP annex | CIVSUB owns population stock. Consumers use deltas/snapshots, not direct identity mutation. |
| `threat_v0_*`, IED/VBIED/suicide runtime state | L8 Threat Synthesis | Threat / IED | Threat baseline + State Ownership Ledger where replicated | Intel, TASKENG, EOD, UI | Threat owns lifecycle and allow/deny decisions. Physical manifestation remains incident/runtime gated. |
| `ARC_dynamic_tod_*` | L2 Time / Tempo Policy | Core | State Ownership Ledger if replicated + time policy functions | CIVSUB, Threat, Airbase, Ops, UI | Time policy owns canonical phase/window logic. CIVSUB may mirror compatibility variables but must not be canonical owner. |
| World registry / objective index keys | L1 Terrain / World Registry | World | World docs / local state audits | CIVSUB, Threat, TASKENG, SitePop, Airbase, UI overlays | World owns terrain truth. Consumers resolve stable IDs rather than recomputing ad hoc context. |
| Logistics/convoy runtime state | L11 Sustainment / S4 | Logistics | State Ownership Ledger where replicated + logistics docs | S3, medical, dashboard, SITREP | Sustainment owns support state. S3 consumes constraints for follow-on decisions. |
| SitePop / Prison runtime state | L1/L4/L5 operational site presence | SitePop / Prison | Subsystem docs and future state-ledger rows where replicated | Threat, Government, UI, QA | Site population uses world anchors and runtime budget. Prison/government handoff behavior must stay server-mediated. |

---

## 4) Configuration ownership overlay

| Config family | Config class | Ecosystem layer owner(s) | Current or preferred home | Overlay rule |
|---|---|---|---|---|
| Core dev/debug/safe-mode flags | Posture toggle | L3 State / Event / Persistence and L0 Runtime Boundary | `initServer.sqf` with startup audit | Safe mode and debug posture may influence many layers, but Core owns the toggle and audit output. |
| Console VM feature flags | Posture toggle | L12 Interface | `initServer.sqf` with startup audit | UI migration flags change rendering path only. They must not alter authoritative gameplay behavior. |
| UI / in-world action flags | Posture toggle | L12 Interface plus validating gameplay layer | `initServer.sqf` with startup audit | Toggle controls action visibility. Authoritative result belongs to the server handler layer. |
| World objective index weights and thresholds | Tuning constant | L1 Terrain / World Registry | `data/ARC_ConfigData.sqf` preferred | Terrain scoring values belong to World, even when TASKENG consumes the ranked result. |
| Threat virtual spawn/patrol/despawn tuning | Tuning constant | L8 Threat Synthesis and L0 Runtime Boundary | `data/ARC_ConfigData.sqf` preferred | Threat owns intent and lifecycle. Runtime owns budget/degradation constraints. |
| OPFOR patrol class pools | Class pool | L6 OPFOR Network / L8 Threat Synthesis | `data/ARC_ConfigData.sqf` preferred | Class pools are data. Threat/OPFOR logic decides whether to use them. |
| CIVSUB enable/scheduler/rumor/debug flags | Posture toggle | L4 Civilian / Population | `initServer.sqf` with startup audit | CIVSUB owns civilian/population posture. Consumers must handle disabled or stale CIVSUB state. |
| CIVSUB population, identity, scheduler, sampler, and cap tuning | Tuning constant | L4 Civilian / Population and L0 Runtime Boundary | `data/ARC_ConfigData.sqf` or subsystem init | CIVSUB owns behavior. Runtime owns global budget pressure. |
| CIVSUB civilian class pools | Class pool | L4 Civilian / Population | `data/ARC_ConfigData.sqf` preferred | Class availability is data. CIVSUB owns physical sampling decisions. |
| CIVTRAF traffic flags and tuning | Posture toggle / tuning constant | L4 Civilian / Population and L0 Runtime Boundary | `initServer.sqf`, `data/ARC_ConfigData.sqf`, or traffic init as classified | Traffic is civilian ambience. Runtime policy may reduce or disable physical activity. |
| CIVLOC location NPC flags and tuning | Posture toggle / tuning constant | L4 Civilian / Population, L1 Terrain / World Registry | `initServer.sqf` or subsystem init as classified | LocNPC depends on world anchors but owns civilian presence behavior. |
| Airbase tower tokens and authorization flags | Posture toggle / token registry | L7 BLUFOR Footprint, L12 Interface | `initServer.sqf` for toggles, `data/ARC_ConfigData.sqf` for token data | Tokens are data. Server authorization owns final decision. |
| Airbase arrival/departure/queue/runway tuning | Tuning constant | L7 BLUFOR Footprint and L8 operational synthesis | `data/ARC_ConfigData.sqf` or airbase init | Airbase owns queue and runway lifecycle. Runtime policy can constrain ambience. |
| IED/EOD detection, evidence, and disposition flags | Posture toggle / tuning constant | L8 Threat Synthesis | `initServer.sqf` for posture, `data/ARC_ConfigData.sqf` for tuning | Threat/EOD lifecycle owns meaning. UI actions must be role/state gated. |
| VBIED/suicide behavior flags and tuning | Posture toggle / tuning constant | L8 Threat Synthesis | `initServer.sqf` or threat config as classified | Scaffolding or unlocked behavior must not expand without locked spec/update. |
| Logistics/convoy class pools and tuning | Class pool / tuning constant | L11 Sustainment / S4 | `data/ARC_ConfigData.sqf` preferred | Sustainment owns support assets. Runtime owns cap/degradation constraints. |
| Medical tuning and CASEVAC posture | Posture toggle / tuning constant | L11 Sustainment / S4 | subsystem config or `data/ARC_ConfigData.sqf` as classified | Medical owns casualty/readiness meaning. S3 consumes constraints. |
| SitePop / Prison templates and staffing pools | Class pool / tuning constant | L1 Terrain / World Registry, L4 Civilian / Population, L5 Government / GREEN | site templates / data config | World anchors drive placement. Government/prison semantics must stay server-mediated. |
| Dynamic TOD activity windows | Tuning constant | L2 Time / Tempo Policy | Core time policy config preferred | Time owns canonical phase/window policy. CIVSUB compatibility mirrors must not become source of truth. |
| Runtime-derived caches and counters | Runtime-derived state | Producing layer plus L3 if public | subsystem init or publisher | Runtime-derived values should be computed by the owner, not authored as constants. |

---

## 5) Ambiguity resolution rules

Use these rules when a state/config value appears to belong to more than one layer.

1. **Producer wins for ownership.** The layer that produces or mutates authoritative state owns it.
2. **Consumer does not inherit ownership.** A UI tab, tasking function, or threat scheduler may consume a value without owning it.
3. **Config intent controls classification.** A variable flipped by operators is a posture toggle. A numeric behavior value is tuning. A classname list is a class pool. A computed map/counter/cache is runtime-derived state.
4. **Cross-layer configs require primary and constraint owner.** Example: threat spawn tuning belongs to Threat, but Runtime Boundary may constrain it under degraded mode.
5. **UI flags own rendering path only.** A UI toggle never owns the authoritative gameplay state changed by a server request.
6. **Time policy owns canonical phase/window decisions.** CIVSUB, Threat, Airbase, and Ops may consume or mirror time policy, but they should not define the canonical phase model.
7. **World registry owns spatial truth.** Other layers should resolve terrain through stable world IDs or documented lookup APIs rather than recomputing local terrain facts.
8. **Planning layers cannot claim runtime ownership.** Government and OPFOR Network planning rows need narrower specs before they add persistent state or hidden schedulers.

---

## 6) Pre-code ownership checklist

Before any implementation PR that touches state or config, answer these questions in the PR body or linked design note:

- [ ] Which ecosystem layer owns the state/config family?
- [ ] Which subsystem owns the writer or config home?
- [ ] Is this authoritative state, public snapshot, client UI state, posture toggle, tuning constant, class pool, or runtime-derived state?
- [ ] Does the State Ownership Ledger need a new or changed writer row?
- [ ] Does the Configuration Ownership Ledger need a new or changed classification row?
- [ ] Does the Layer Contract Ledger need a status, test, event, cadence, or failure-mode update?
- [ ] Does any UI consumer read this through Console VM or documented `ARC_pub_*` state?
- [ ] Does any RemoteExec endpoint need S0-S5 audit updates?
- [ ] Does this create a runtime-validation obligation in `tests/TEST-LOG.md`?

If the answer is unclear, do not implement yet. Write the ownership update first.

---

## 7) Overlay update triggers

| Trigger | Required update |
|---|---|
| New replicated key | State Ownership Ledger row plus this overlay if it creates a new state family. |
| New public snapshot section | State Ownership Ledger, Layer Contract Ledger, this overlay, and Console VM docs if UI-facing. |
| New operator-visible config | Configuration Ownership Ledger and this overlay if layer ownership is not already covered. |
| Config relocation | Configuration Ownership Ledger target home update and this overlay if layer ownership changes. |
| New hidden network/governance state | Narrow planning spec first, then State Ownership Ledger and this overlay. |
| New scheduler | Layer Contract Ledger cadence and L0 runtime-budget review. |
| New feedback loop | Ecosystem feedback catalog, affected layer rows, and this overlay if state/config ownership changes. |
| Runtime proof completed | Test log update first; then layer status updates if the proof changes classification. |

---

## 8) Known overlay gaps

These are intentional gaps, not permission to implement around the ledger.

| Gap | Why it remains open | Next action |
|---|---|---|
| Full key-by-key ecosystem owner columns inside `State_Ownership_Ledger.md` | This PR creates the overlay first to avoid a noisy full-ledger rewrite. | Add layer-owner columns opportunistically when key rows are touched. |
| Full variable-by-variable ecosystem owner columns inside `Configuration_Ownership_Ledger.md` | This PR creates a family-level overlay first. | Add layer-owner annotations during future config relocation or audit PRs. |
| Government / GREEN runtime keys | Government layer is still planning-first. | Write a narrow Government Layer planning spec before runtime state. |
| OPFOR Network runtime keys | OPFOR capacity is conceptually separate from Threat manifestation, but not yet a locked runtime spec. | Write an OPFOR Network planning spec before persistent hidden state. |
| Runtime Boundary policy keys | Runtime policy is planned but not implemented. | Define `ARC_runtimePolicy_v1` before code. |
| BLUFOR readiness read model | State exists across several subsystems. | Define a BLUFOR readiness read model before broad consumers expand. |

---

## 9) Relationship to active documents

| Document | Relationship |
|---|---|
| `docs/architecture/Farabad_Ecosystem_Architecture_v1.md` | Defines the ecosystem layer model and dependency direction. |
| `docs/architecture/Layer_Contract_Ledger.md` | Defines per-layer contracts. This overlay maps state/config families to those layers. |
| `docs/architecture/State_Ownership_Ledger.md` | Remains the canonical key-level writer ledger. This overlay does not replace it. |
| `docs/architecture/Configuration_Ownership_Ledger.md` | Remains the canonical config classification ledger. This overlay does not replace it. |
| `docs/architecture/Console_VM_v1.md` | UI state consumption must move toward Console VM sections or documented public snapshots. |
| `docs/security/RemoteExec_Endpoint_Audit_Matrix.md` | Any state/config change that affects request surfaces must update RPC security status. |
| `docs/qa/Pre_Dedicated_Mission_Completion_Audit_2026-04-06.md` | Runtime status in this overlay must not override the completion ledger. |
| `tests/TEST-LOG.md` | Runtime claims require current-head evidence here before release-readiness claims. |

---

## 10) Update policy

Update this overlay when any of the following changes:

- A new state family appears.
- A public snapshot changes ownership or consumer scope.
- A config family relocates or changes classification.
- A layer owner changes for a state/config family.
- A planned layer becomes runtime implementation.
- A future architecture plan changes subsystem boundaries, ecosystem layers, or non-goals.
