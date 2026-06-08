# Farabad COIN v0 - Ecosystem Architecture v1

**Version:** 1.0  
**Date:** 2026-06-08  
**Status:** Active planning contract  
**Mode:** F - Documentation-Only Changes  
**Scope:** Architecture contract, layer ownership model, dependency direction, feedback-loop catalog, and refactor sequencing. No runtime behavior changes.

---

## 0) Truth status

This document was authored from `main` at commit `ccfb7a1c59d9ade63d5fdf252445bff6d64df5a4` and proposed on branch `docs/ecosystem-architecture-v1`.

Truth classification:

| Claim type | Status |
|---|---|
| Current source references already present in `main` | Main-confirmed at authoring base commit |
| New ecosystem architecture language in this document | Branch-local until merged |
| Runtime behavior claims introduced by this document | None. This document changes planning language only |

Do not treat this document as proof that a runtime path works. Runtime behavior still requires validation through the active QA ledgers and `tests/TEST-LOG.md`.

---

## 1) Purpose

Farabad COIN should operate as a server-authoritative ecosystem, not as a collection of isolated subsystems. This document defines the ecosystem layer model that guides future documentation, audits, refactors, and feature work.

The model starts with terrain and runtime boundaries, then moves through time, population, governance, OPFOR, BLUFOR, threat, intel, operations, sustainment, and player-facing interface. Each layer must publish explicit state or events for higher layers. No layer should infer hidden state from another subsystem.

This document does not replace these active authorities:

- `docs/architecture/Architecture_Plan_2026-05-08.md`
- `docs/planning/Task_Decomposition.md`
- `docs/qa/Pre_Dedicated_Mission_Completion_Audit_2026-04-06.md`
- `docs/architecture/State_Ownership_Ledger.md`
- `docs/architecture/Configuration_Ownership_Ledger.md`
- `docs/architecture/Console_VM_v1.md`
- `docs/security/RemoteExec_Endpoint_Audit_Matrix.md`
- `docs/projectFiles/Farabad_COIN_Mission_Design_Guide_v0.4_2026-01-27.md`

This document adds one missing framing layer: how those existing contracts compose into an ecosystem.

---

## 2) Non-goals

This architecture contract does not authorize any of the following by itself:

- Redesigning the server-authoritative state model.
- Redesigning persistence schemas.
- Rewriting `ARC_fnc_stateGet`, `ARC_fnc_stateSet`, or `ARC_fnc_publicBroadcastState`.
- Replacing the Farabad Console shell.
- Adding new RemoteExec endpoints during hardening phases.
- Moving large groups of SQF files just to match the layer names.
- Treating static review as dedicated/JIP proof.

If an implementation task needs any of those changes, update the active architecture plan through a versioned bump before implementation.

---

## 3) Ecosystem strata

The project should reason about Farabad COIN through four strata.

| Stratum | Purpose | Layers |
|---|---|---|
| Foundation | Defines the world and runtime conditions that every other system can trust | Runtime Boundary, Terrain / World Registry, Time / Tempo Policy, State / Event / Persistence, Observability |
| Society and actors | Defines who lives, governs, threatens, and operates inside the AO | Civilian, Government, OPFOR Network, BLUFOR Footprint |
| Operational synthesis | Converts world state and actor behavior into playable COIN pressure and command decisions | Threat, Intel / S2, Operations / S3, Sustainment / S4, Airbase / CASREQ, Medical, SitePop / Prison |
| Player experience | Shows authorized players fresh-enough state and routes actions through validated request paths | Farabad Console, Console VM, Helpers, Toasts, addActions, role/station UI |

The layer model is not a directory map. It is an ownership and dependency model. Existing subsystem folders may remain where they are as long as state ownership, event flow, and validation boundaries remain explicit.

---

## 4) Dependency direction

The default dependency direction is:

```text
Runtime Boundary
  -> Terrain / World Registry
  -> Time / Tempo Policy
  -> Civilian / Government / OPFOR / BLUFOR
  -> Threat / Intel / Operations / Sustainment / Airbase / Medical / SitePop
  -> Interface / Console VM
```

Rules:

1. Lower layers do not call upward for gameplay decisions.
2. Higher layers consume lower-layer snapshots, delta bundles, or validated service APIs.
3. Cross-subsystem integration uses bounded event envelopes.
4. UI code renders from Console VM sections or documented `ARC_pub_*` snapshots.
5. Client actions follow `client request -> server validation -> authoritative mutation -> snapshot refresh`.
6. Any direct read across subsystem internals requires an audit note and a migration task.

Allowed exceptions must be documented in the Layer Contract Ledger and State Ownership Ledger.

---

## 5) Layer Contract Ledger schema

Every layer entry should define the following fields before implementation work expands that layer.

| Field | Required content |
|---|---|
| Layer ID | Stable ID such as `L0_RUNTIME`, `L1_WORLD`, or `L7_THREAT` |
| Owner subsystem | Primary subsystem or document owner |
| Authority | Server-only, client-only, or mixed with exact boundaries |
| Inputs | Snapshots, delta bundles, config values, or engine facts the layer consumes |
| Outputs | Public snapshots, internal stores, event envelopes, UI VM sections, or logs |
| State keys | Authoritative keys, runtime keys, replicated keys, and persistence keys |
| Writer functions | The only functions allowed to mutate authoritative or replicated state |
| Event types | Delta-bundle names and critical lifecycle logs |
| Tick cadence | Scheduler interval, trigger event, or no-tick behavior |
| Persistence | Schema version, save/load path, migration rules, and reset behavior |
| Runtime budget | AI cap, spawn cap, scheduler budget, or degraded-mode behavior |
| UI exposure | Console VM section, tab, helper, toast, or no UI exposure |
| Tests | Static, hosted MP, dedicated, JIP, reconnect, respawn, and persistence proof |
| Failure mode | How the layer degrades without corrupting state or blocking the mission spine |

A layer without these fields remains planning-only.

---

## 6) Initial layer ledger

| Layer | Owner | Primary role | Current implementation posture | Next architecture task |
|---|---|---|---|---|
| L0 Runtime Boundary | Core / QA | Represents server mode, player count, scheduler budget, AI budget, cleanup pressure, and JIP posture | Partially implicit across cleanup, schedulers, player snapshots, and QA docs | Define `ARC_runtimePolicy_v1` planning contract before code work |
| L1 Terrain / World Registry | World | Owns named locations, zones, terrain sites, protected zones, routes, objective index, and world anchors | Existing world functions already index locations and objectives | Normalize as `World Registry` contract without moving files |
| L2 Time / Tempo Policy | Core | Owns TOD phase, peak/night/day profile, spawn windows, traffic windows, and tempo hints | Existing dynamic TOD policy exists, but CIVSUB activity config currently drives phase windows | Extract canonical time ownership from CIVSUB-facing config through compatibility wrappers |
| L3 State / Event / Persistence | Core | Owns authoritative state, public snapshots, delta-bundle discipline, persistence, logging, and reset workflows | Strong current baseline through state functions and ledgers | Extend ledgers with ecosystem layer ownership |
| L4 Civilian / Population | CIVSUB | Owns virtual population, physical civilian sampling, touched identities, crime DB, and district influence | CIVSUBv1 is a locked baseline and live subsystem | Audit output events and add layer metadata where useful |
| L5 Government / GREEN | CIVSUB / future Gov bridge | Owns governance legitimacy, police/military response, corruption, agencies, and public-service posture | Mostly represented through GREEN influence and specific handoff flows | Write Government Layer planning spec before runtime expansion |
| L6 OPFOR Network | Threat / future OPFOR bridge | Owns cells, facilitators, safehouses, intimidation, recruitment, disruption, and capacity | Threat currently carries much of this pressure | Separate network capacity from threat manifestation in planning first |
| L7 BLUFOR Footprint | Core / Command / Logistics / Medical / Airbase | Owns player groups, AI BLUFOR, base posture, unit readiness, and operational presence | Implemented across several subsystems | Define a BLUFOR readiness read model before broad consumers expand |
| L8 Threat Synthesis | Threat / IED | Converts district posture, OPFOR capacity, terrain, time, and player conduct into threat records, leads, and attacks | Threat scheduler, economy, records, and IED paths exist | Run reliability sweep before adaptive behavior changes |
| L9 Intel / S2 | Intel / TASKENG | Converts hidden state into leads, confidence, uncertainty, and source quality | Intel functions exist, but confidence coupling needs fuller contract | Define intel quality inputs and lead fidelity fields |
| L10 Operations / S3 | TASKENG / SITREP / Command | Owns task, lead, SITREP, queue, orders, follow-on decisions, and mission pacing | Mission spine exists and has gate evaluators | Reliability sweep plus follow-on policy matrix |
| L11 Sustainment / S4 | Logistics / Medical | Owns ammo, liquids, casualties, equipment, fuel, repair, detainee transport, CASEVAC, and resupply | Implemented across logistics, medical, and SITREP annexes | Define a sustainment readiness snapshot |
| L12 Interface | UI / Console VM | Renders authorized, fresh-enough state and routes actions through validated request paths | Console VM exists and migration remains phased | Map each tab to VM sections and remove direct-read debt by parity |

---

## 7) State and event rules

### 7.1 State categories

Farabad should keep three state categories explicit:

| Category | Writer | Consumer |
|---|---|---|
| Authoritative persistent state | Server only | Server systems |
| Published public snapshots | Server publisher only | Clients and UI |
| Client UI state | Client only | Local UI render and selection logic |

No gameplay system should treat client UI state as authoritative.

### 7.2 Event envelopes

Cross-layer events should use bounded envelopes. Each event should include:

- Event ID.
- Schema/version.
- Server timestamp.
- Producer layer.
- Producer subsystem.
- Actor context when available.
- Target context when available.
- District ID when spatially relevant.
- Position/grid/marker when available.
- Bounded payload.
- Optional influence deltas.
- Optional task/lead hints.
- Idempotency key when duplicate handling matters.

### 7.3 Public snapshots

Public snapshots should be presentation-oriented, bounded, and JIP-safe. They should not become unbounded mirrors of internal stores.

Every public snapshot should expose freshness metadata or a companion updated-at key. UI should keep rendering the last known value and show stale state rather than clearing to false no-data states.

---

## 8) Feedback-loop catalog

| Loop | Type | Inputs | Outputs | Design use |
|---|---|---|---|---|
| Disciplined COIN loop | Reinforcing | Proportional force, aid, lawful detention, clean SITREPs, persistent presence | Higher WHITE/GREEN, better intel, more precise tasks, lower OPFOR freedom | Reward disciplined play without making the AO passive |
| Heavy-handed backlash loop | Reinforcing | Civilian casualties, unlawful detention, property damage, poor reporting | Lower WHITE/GREEN, higher fear/RED, worse intel, more attacks | Make careless action create operational cost |
| Threat suppression loop | Balancing | Successful raids, evidence collection, cell disruption, detainee handoff | Reduced capacity, cooldowns, lower local risk | Prevent constant spawn pressure after effective operations |
| Overextension loop | Balancing | Low ammo, casualties, liquids, damaged vehicles, fatigue of operational tempo | RTB/Hold/resupply/CASEVAC recommendations | Make sustainment constrain follow-on pacing |
| Server protection loop | Balancing | Player count, AI count, active schedulers, server degradation posture | Lower ambience budgets, virtualized simulation, deferred spawns | Preserve mission spine when performance pressure rises |
| Intel uncertainty loop | Balancing | Low trust, intimidation, unstable districts, weak source quality | Less precise leads, delayed warnings, uncertainty labels | Force reconnaissance and population work before precise action |

Feedback loops should change probabilities, confidence, cooldowns, budgets, task hints, or UI explanations. They should not bypass server authority or spawn directly from UI actions.

---

## 9) Implementation sequence

Use this sequence for ecosystem-related work.

| Step | Mode | Work |
|---|---|---|
| 1 | F | Add this ecosystem architecture contract and cross-link it from active planning docs |
| 2 | F | Extend State Ownership and Configuration Ownership ledgers with layer ownership |
| 3 | F | Audit direct cross-subsystem reads and upward dependency violations |
| 4 | F | Define Runtime Boundary, World Registry, and Time Policy contracts |
| 5 | C | Add compatibility wrappers for time/world/runtime read models without behavior change |
| 6 | J | Run CIVSUB / Threat / IED reliability sweep before adaptive behavior changes |
| 7 | B | Add threat economy reason taxonomy and district-posture-driven event selection |
| 8 | B | Add intel quality coupling and lead fidelity surfacing |
| 9 | J | Run TASKENG / SITREP / follow-on reliability sweep |
| 10 | B | Add sustainment readiness snapshot and follow-on policy hints |
| 11 | C/B | Continue Console VM migration tab by tab with parity evidence |
| 12 | I | Update RemoteExec matrix for changed request/action paths |
| 13 | J | Run dedicated/JIP ecosystem validation |

Each PR must use exactly one primary mode under `AGENTS.md`. Split mixed-mode work into separate PRs.

---

## 10) Acceptance criteria for ecosystem health

Farabad should count the ecosystem architecture as healthy when all of these are true:

1. Every layer has a documented owner, inputs, outputs, state keys, writer functions, events, tick cadence, persistence/reset behavior, runtime budget, UI exposure, and tests.
2. Every replicated `missionNamespace` key maps to a subsystem owner and an ecosystem layer owner.
3. Every operator-visible config value maps to a subsystem owner and layer owner.
4. No foundation layer depends on a higher gameplay layer for canonical policy.
5. No client UI tab mutates authoritative state or infers hidden state from partial messages.
6. Cross-system interactions use delta bundles, public snapshots, or validated service requests.
7. Threat pressure uses district posture, OPFOR capacity, recent conduct, terrain, time, cooldowns, and budgets rather than disconnected random spawning.
8. Intel quality exposes confidence and uncertainty without exposing hidden scheduler internals.
9. S3 follow-on recommendations consider task outcome, intel, threat, sustainment, time, and district posture.
10. Dedicated/JIP, reconnect, respawn, and persistence behavior have current-head evidence in `tests/TEST-LOG.md`.

---

## 11) Relationship to active documents

| Document | Relationship |
|---|---|
| `docs/architecture/Architecture_Plan_2026-05-08.md` | Remains the active forward architecture roadmap. This ecosystem contract adds a layer-composition model under that roadmap. |
| `docs/planning/Task_Decomposition.md` | Remains the execution-track decomposition. Ecosystem tasks should be tracked there before implementation. |
| `docs/qa/Pre_Dedicated_Mission_Completion_Audit_2026-04-06.md` | Remains the canonical feature-completion ledger before dedicated/JIP validation. Ecosystem work must not create a competing completion board. |
| `docs/architecture/State_Ownership_Ledger.md` | Remains the single-writer ledger. Future updates should add ecosystem layer ownership where useful. |
| `docs/architecture/Configuration_Ownership_Ledger.md` | Remains the config ownership ledger. Future updates should add ecosystem layer ownership where useful. |
| `docs/architecture/Console_VM_v1.md` | Remains the UI view-model contract. Interface-layer work should migrate tabs through this VM rather than adding direct reads. |
| `docs/security/RemoteExec_Endpoint_Audit_Matrix.md` | Remains the live RPC hardening ledger. Ecosystem action paths must update it when request surfaces change. |
| `docs/planning/Subsystem_Reliability_and_Adaptive_COIN_Plan.md` | Remains the reliability and adaptive behavior execution contract. Ecosystem work should preserve its reliability-first sequencing. |
| `AGENTS.md` | Remains the PR-mode and validation doctrine. Ecosystem work must split docs, refactors, features, security, and operations into separate PRs. |

---

## 12) Update policy

Update this document when any of the following changes:

- A layer gains or loses ownership of authoritative state.
- A new public snapshot or event envelope crosses layer boundaries.
- A foundation service moves from implicit to explicit ownership.
- A feedback loop becomes implemented behavior.
- A future architecture plan changes subsystem boundaries, phase order, or hard non-goals.
