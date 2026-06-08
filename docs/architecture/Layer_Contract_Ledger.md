# Farabad COIN v0 - Layer Contract Ledger

**Version:** 1.0  
**Date:** 2026-06-08  
**Status:** Active architecture ledger  
**Mode:** F - Documentation-Only Changes  
**Parent contract:** `docs/architecture/Farabad_Ecosystem_Architecture_v1.md`  
**Scope:** Per-layer ownership, state, events, public surfaces, tests, failure modes, and next contract tasks. No runtime behavior changes.

---

## 0) Truth status

This ledger was authored from `main` at commit `ccfb7a1c59d9ade63d5fdf252445bff6d64df5a4` and proposed on branch `docs/ecosystem-architecture-v1`.

Truth classification:

| Claim type | Status |
|---|---|
| Existing source and architecture references already present in `main` | Main-confirmed at authoring base commit |
| Layer ownership assignments introduced by this ledger | Branch-local until merged |
| Runtime behavior claims introduced by this ledger | None. This document changes planning and audit language only |

This ledger does not prove runtime behavior. Dedicated/JIP, reconnect, respawn, persistence, and full mod-stack behavior still require current-head evidence in `tests/TEST-LOG.md`.

---

## 1) Purpose

The Layer Contract Ledger is the enforceable companion to `Farabad_Ecosystem_Architecture_v1.md`. The ecosystem document defines the model. This ledger forces each layer to declare ownership, state, events, public surfaces, tests, and failure behavior before implementation expands that layer.

Use this ledger when any PR does one or more of the following:

- Adds a public snapshot, VM section, or event envelope.
- Adds or relocates an authoritative writer.
- Adds a subsystem scheduler or changes a scheduler cadence.
- Changes a config value that affects more than one subsystem.
- Changes UI action routing or role/station visibility.
- Adds feedback behavior that changes threat, intel, tasking, sustainment, or population outcomes.

---

## 2) Ledger status legend

| Status | Meaning |
|---|---|
| `ACTIVE` | Contract is usable for implementation guidance now. |
| `PARTIAL` | Layer exists in shipped systems, but the contract is incomplete or distributed across docs/code. |
| `PLANNING` | Concept is accepted, but runtime implementation should not expand until a narrower spec exists. |
| `NEEDS_AUDIT` | Current implementation likely exists, but ownership, state keys, or consumers need review before further work. |
| `BLOCKED_RUNTIME` | Static contract exists, but runtime behavior needs hosted/dedicated/JIP proof. |

A layer can have more than one status. Example: `PARTIAL / BLOCKED_RUNTIME` means implementation exists, but runtime proof is not complete.

---

## 3) Hard rules

1. A layer must have one declared owner for each authoritative state family.
2. A layer may have multiple consuming subsystems, but consumers must use public snapshots, delta bundles, or validated service requests.
3. UI is never an authority layer. UI may request actions and render state, but it must not infer hidden state or mutate authoritative stores.
4. Foundation layers must not depend on higher gameplay layers for canonical policy.
5. A runtime behavior change that touches more than one layer must update this ledger or cite an existing row that already covers the change.
6. A layer row marked `PLANNING` cannot justify runtime expansion by itself. Create a narrower implementation spec first.
7. A layer row marked `BLOCKED_RUNTIME` cannot support a release-readiness claim until `tests/TEST-LOG.md` has current-head evidence.

---

## 4) Layer summary matrix

| Layer ID | Layer | Stratum | Primary owner | Status | Enforcement point |
|---|---|---|---|---|---|
| L0 | Runtime Boundary | Foundation | Core / QA | PLANNING / NEEDS_AUDIT | Before new scheduler, AI cap, cleanup, or degradation behavior |
| L1 | Terrain / World Registry | Foundation | World | PARTIAL | Before new terrain consumer, site anchor, route, or protected-zone dependency |
| L2 | Time / Tempo Policy | Foundation | Core | PARTIAL / NEEDS_AUDIT | Before new time-of-day, traffic, civilian, threat, or airbase window logic |
| L3 | State / Event / Persistence | Foundation | Core | ACTIVE | Before any authoritative state, public snapshot, delta bundle, persistence, or reset change |
| L4 | Civilian / Population | Society and actors | CIVSUB | PARTIAL / BLOCKED_RUNTIME | Before new civilian, district, identity, influence, or rumor behavior |
| L5 | Government / GREEN | Society and actors | CIVSUB / future Gov bridge | PLANNING | Before new governance, police, agency, corruption, or legitimacy behavior |
| L6 | OPFOR Network | Society and actors | Threat / future OPFOR bridge | PLANNING / NEEDS_AUDIT | Before new cell capacity, recruitment, intimidation, disruption, or safehouse logic |
| L7 | BLUFOR Footprint | Society and actors | Core / Command / Logistics / Medical / Airbase | NEEDS_AUDIT | Before new AI BLUFOR, unit readiness, battalion posture, or base footprint behavior |
| L8 | Threat Synthesis | Operational synthesis | Threat / IED | PARTIAL / BLOCKED_RUNTIME | Before new attack selection, threat economy, IED/VBIED/suicide, or lead emission behavior |
| L9 | Intel / S2 | Operational synthesis | Intel / TASKENG | PARTIAL / NEEDS_AUDIT | Before new lead confidence, uncertainty, source quality, or ISR cue behavior |
| L10 | Operations / S3 | Operational synthesis | TASKENG / SITREP / Command | PARTIAL / BLOCKED_RUNTIME | Before new task, queue, SITREP, order, or follow-on decision behavior |
| L11 | Sustainment / S4 | Operational synthesis | Logistics / Medical | PARTIAL / NEEDS_AUDIT | Before new ammo, liquids, casualties, equipment, fuel, CASEVAC, detainee, or resupply behavior |
| L12 | Interface | Player experience | UI / Console VM | PARTIAL / BLOCKED_RUNTIME | Before new console tab, helper, toast, addAction, or action dispatch behavior |

---

## 5) Detailed layer contracts

### L0 - Runtime Boundary

| Field | Contract |
|---|---|
| Owner subsystem | Core / QA |
| Authority | Server-owned policy, client-readable only if published through snapshot/VM. |
| Inputs | Player count, player positions, server mode, active schedulers, active AI/groups/vehicles, cleanup pressure, safe mode, JIP/reconnect posture. |
| Outputs | Planned `ARC_runtimePolicy_v1`, diagnostic snapshot, scheduler budget bands, degradation mode, validation context in `tests/TEST-LOG.md`. |
| State keys | Existing keys need audit. Planned family: `ARC_runtimePolicy_*` or VM section `sections.runtime`. |
| Writer functions | Planned server-only publisher. Current implicit writers are distributed across bootstrap, cleanup, scheduler, and diagnostics paths. |
| Event types | `RUNTIME_POLICY_REFRESH`, `RUNTIME_DEGRADED`, `RUNTIME_RECOVERED`, `SCHEDULER_BUDGET_CHANGED`. Planned taxonomy only. |
| Tick cadence | Planned slow cadence, likely 30-120 seconds, plus event-triggered refresh on major player/server posture changes. |
| Persistence | None unless later needed. Runtime state should be derived on start. |
| Runtime budget | Owns budget policy for AI counts, ambient schedulers, spawn pressure, and degraded mode. |
| UI exposure | Planned Console VM runtime/diagnostics section for operators. No gameplay authority. |
| Tests | Hosted MP player-count smoke, dedicated fresh start, JIP after active scheduler state, reconnect during active world load, degraded-mode RPT review. |
| Failure mode | If runtime policy is unavailable, higher systems must use conservative defaults and avoid expanding spawn pressure. |
| Next task | Define `ARC_runtimePolicy_v1` contract before code. |

### L1 - Terrain / World Registry

| Field | Contract |
|---|---|
| Owner subsystem | World |
| Authority | Server-owned world registry and derived indexes. Clients may consume public presentation snapshots only. |
| Inputs | Mission markers, world locations, buildings, roads, bridges, terrain sites, protected zones, named sites, routes, airbase center, district geometry. |
| Outputs | World registry, objective index, route/site/protected-zone lookup results, location IDs, stable anchor IDs. |
| State keys | Existing families include `ARC_worldNamedLocations`, `ARC_worldTerrainSites`, `ARC_worldZones`, `ARC_worldObjectiveIndex`, `ARC_worldObjectiveRanked`. Complete key audit pending. |
| Writer functions | World init and world indexing functions. No other layer should mutate world-derived registry state. |
| Event types | `WORLD_REGISTRY_BUILT`, `WORLD_OBJECTIVE_INDEX_BUILT`, `WORLD_ANCHOR_MISSING`, `PROTECTED_ZONE_RESOLVED`. Planned taxonomy where not already logged. |
| Tick cadence | Bootstrap-derived. No continuous tick unless a future dynamic-world feature explicitly adds one. |
| Persistence | Usually none. Derived from mission data at start. Any future persistence requires schema/version/reset entry. |
| Runtime budget | Supports spawn-site selection and protected-zone checks. Does not own AI budgets. |
| UI exposure | Map overlays, site labels, objective metadata, debug diagnostics. |
| Tests | Static marker validation, hosted MP anchor smoke, dedicated fresh start, JIP map/console display, protected-zone exclusion proof. |
| Failure mode | Missing anchors should log clear warnings and deny dependent spawns rather than guessing. |
| Next task | Define `World Registry` contract and consumer list before converting more systems. |

### L2 - Time / Tempo Policy

| Field | Contract |
|---|---|
| Owner subsystem | Core |
| Authority | Server computes canonical time/tempo policy. Clients read replicated policy or VM section. |
| Inputs | Mission `dayTime`, time acceleration, mission date/calendar if used, activity windows, safe mode, runtime policy. |
| Outputs | TOD phase, profile, spawn windows, civilian activity window, traffic window, airbase window, threat window, ops tempo hints. |
| State keys | Existing family includes `ARC_dynamic_tod_*` and compatibility mirrors into CIVSUB activity variables. Complete ownership audit pending. |
| Writer functions | `ARC_fnc_dynamicTodRefresh` currently writes dynamic TOD state. Future wrapper should clarify time ownership. |
| Event types | `TIME_POLICY_REFRESH`, `TIME_PHASE_CHANGED`, `TEMPO_WINDOW_CHANGED`. Planned taxonomy only. |
| Tick cadence | Lazy refresh today. Future cadence should be explicit and low-frequency. |
| Persistence | None expected. Derived from mission time and config. |
| Runtime budget | Indirect. Time may alter allowed windows, but runtime policy owns budget pressure. |
| UI exposure | Optional dashboard/diagnostic display. Most use should be indirect through subsystem snapshots. |
| Tests | Static ownership audit, hosted MP day/night/peak transition smoke, JIP after phase transition, RPT proof that consumers do not define canonical phase policy. |
| Failure mode | If time policy is missing, consumers use safe daytime/default behavior and log stale/missing policy. |
| Next task | Extract canonical time ownership from CIVSUB-facing config through a compatibility wrapper. |

### L3 - State / Event / Persistence

| Field | Contract |
|---|---|
| Owner subsystem | Core |
| Authority | Server-only authoritative state and public snapshot publishing. Client UI state remains local and non-authoritative. |
| Inputs | Subsystem requests, validated RPCs, delta bundles, internal authoritative stores, persistence blobs. |
| Outputs | `ARC_state`, `ARC_pub_*` snapshots, bounded logs, delta-bundle routes, persistence save/load/reset behavior. |
| State keys | Governed by `State_Ownership_Ledger.md`, subsystem baselines, and persistence docs. |
| Writer functions | `ARC_fnc_stateSet`, `ARC_fnc_publicBroadcastState`, and designated subsystem broadcast functions only. |
| Event types | All critical lifecycle events, including task, SITREP, threat, CASREQ, airbase, medical, logistics, and security events. |
| Tick cadence | Varies by publisher. Each cadence must be documented by subsystem owner. |
| Persistence | Versioned, migratable, resettable. Persisted stores must have schema version and no-op migration behavior where appropriate. |
| Runtime budget | Owns bounded stores and snapshot caps. Does not own AI budgets. |
| UI exposure | Public snapshots and Console VM source material only. |
| Tests | Migration test, reset/rebuild test, static single-writer audit, dedicated save/load, JIP snapshot reconstruction, reconnect proof. |
| Failure mode | On missing/invalid state, publish safe empty bounded snapshots and log structured errors. Do not infer state on clients. |
| Next task | Add ecosystem layer owner columns where useful in state/config ledgers. |

### L4 - Civilian / Population

| Field | Contract |
|---|---|
| Owner subsystem | CIVSUB |
| Authority | Server owns district influence, identities, crime DB, civilian sampling, and civilian interaction outcomes. Clients request interactions only. |
| Inputs | Terrain districts, time policy, runtime policy, player interactions, casualties, aid, detentions, threat pressure, government posture. |
| Outputs | District snapshots, touched identities, crime hits, CIVSUB delta bundles, SITREP annex data, lead/rumor/event hints. |
| State keys | `civsub_v1_*` families, district maps, identity maps, crime DB, scheduler state. Full key ownership remains in subsystem docs/ledger. |
| Writer functions | CIVSUB init/tick/delta/identity/contact/persistence functions. Client contact UI must not write authoritative state. |
| Event types | `CIVSUB_DELTA`, `CIV_TOUCHED`, `CIV_AID_GIVEN`, `CIV_DETAINED`, `CIV_RELEASED`, `CIV_HARMED`, `CIV_RUMOR_EMITTED`. Some events may need taxonomy alignment. |
| Tick cadence | CIVSUB tick, scheduler tick, civilian sampler tick, traffic tick. Exact cadences must remain subsystem-owned and runtime-budget-aware. |
| Persistence | District state, touched identities, and crime DB must remain versioned and resettable. |
| Runtime budget | Physical civilians are samples of virtual population and must respect player bubble and caps. |
| UI exposure | Console CIVSUB snapshots, contact dialogs, SITREP CIVSUB annex, role-gated reports. |
| Tests | Full mod-stack CIVSUB sampling, touched identity persistence, district delta validation, JIP observer, hosted MP contact flow, dedicated restart. |
| Failure mode | If physical civilian sampling is degraded, virtual population remains authoritative and physical spawns reduce or stop. |
| Next task | Audit CIVSUB output events and add layer metadata where useful. |

### L5 - Government / GREEN

| Field | Contract |
|---|---|
| Owner subsystem | CIVSUB / future Government bridge |
| Authority | Server-owned posture. Clients may request or report interactions only. |
| Inputs | GREEN legitimacy, TNP/TNA presence, detention handoffs, aid delivery, checkpoint status, corruption events, civilian sentiment, threat pressure. |
| Outputs | Government posture snapshot, GREEN deltas, police/agency response events, governance failure/success events. |
| State keys | Planning only. Existing GREEN values live through CIVSUB district state. Future `gov_v1_*` keys require separate spec. |
| Writer functions | Planning only. Future writers must be server-only and documented before implementation. |
| Event types | `GOV_POSTURE_CHANGED`, `TNP_RESPONSE`, `TNA_RESPONSE`, `CHECKPOINT_STATUS_CHANGED`, `CORRUPTION_EVENT`, `DETAINEE_HANDOFF_ACCEPTED`. Planned taxonomy only. |
| Tick cadence | Planning only. Prefer event-driven first, not a new always-on scheduler. |
| Persistence | Planning only. Future posture/history needs schema/version/reset. |
| Runtime budget | Should prefer virtual posture and bounded response units. |
| UI exposure | Command dashboard, district governance view, SITREP annex, detainee/prison handoff status. |
| Tests | Planning spec first, then hosted MP handoff smoke, GREEN delta verification, JIP posture snapshot, dedicated restart if persisted. |
| Failure mode | If government layer is unavailable, CIVSUB GREEN remains the minimal governance signal. |
| Next task | Write Government Layer planning spec before runtime expansion. |

### L6 - OPFOR Network

| Field | Contract |
|---|---|
| Owner subsystem | Threat / future OPFOR bridge |
| Authority | Server owns hidden OPFOR network capacity and disruption state. Clients receive only intel-filtered exposure. |
| Inputs | RED influence, district fear, OPFOR cell records, terrain opportunities, time policy, player operations, detainee/evidence outcomes, government posture. |
| Outputs | Cell capacity, facilitator/safehouse posture, intimidation/recruitment pressure, disruption/recovery events, threat synthesis inputs. |
| State keys | Planning only. Some pressure currently lives in Threat records/economy. Future `opfor_v1_*` keys require separate spec. |
| Writer functions | Planning only. Future writers must be server-only and hidden-state safe. |
| Event types | `OPFOR_CELL_DISRUPTED`, `OPFOR_CELL_RECOVERED`, `FACILITATOR_ACTIVE`, `SAFEHOUSE_COMPROMISED`, `INTIMIDATION_PRESSURE_CHANGED`. Planned taxonomy only. |
| Tick cadence | Planning only. Prefer event-driven plus slow recovery tick if needed. |
| Persistence | Likely required for persistent campaign behavior, but not authorized by this ledger alone. |
| Runtime budget | Network state should be mostly virtual. Physical manifestations occur through Threat/Tasking. |
| UI exposure | Never raw. Only through Intel confidence, leads, threat records, and narrative reports. |
| Tests | Planning spec first, then static hidden-state audit, threat scheduler consumer test, incident disruption feedback, JIP snapshot secrecy check. |
| Failure mode | If OPFOR network is unavailable, Threat uses existing economy/governor inputs and logs that OPFOR capacity input is absent. |
| Next task | Separate OPFOR network capacity from Threat manifestation in planning. |

### L7 - BLUFOR Footprint

| Field | Contract |
|---|---|
| Owner subsystem | Core / Command / Logistics / Medical / Airbase |
| Authority | Server owns public BLUFOR readiness/posture snapshots. Player clients submit status/request data through validated flows. |
| Inputs | S1 registry, player groups, AI BLUFOR, unit statuses, task acceptance, SITREP payloads, medical state, logistics state, airbase/base posture. |
| Outputs | Unit readiness, base posture, battalion AO footprint, AI BLUFOR availability, tasking constraints, sustainment consumers. |
| State keys | Existing families include S1 registry, company command, unit statuses, medical snapshots, airbase snapshots. Full map requires audit. |
| Writer functions | Core/company command, medical broadcaster, logistics/airbase publishers, task/SITREP lifecycle functions. |
| Event types | `BLUFOR_STATUS_CHANGED`, `UNIT_READYNESS_UPDATED`, `AI_BLUFOR_ASSIGNED`, `BASE_POSTURE_CHANGED`, `GROUP_BOUND_TO_TASK`. Planned taxonomy where not already logged. |
| Tick cadence | Mixed event-driven and scheduled. Must not create another unbounded scheduler. |
| Persistence | Unit/task state persists through existing systems where required. Readiness snapshot should be derivable unless explicitly persisted. |
| Runtime budget | AI BLUFOR must respect Runtime Boundary budgets. |
| UI exposure | S1, company command, tasking, SITREP, airbase, medical, and dashboard VM sections. |
| Tests | S1 registry smoke, active task/JIP readiness reconstruction, reconnect/respawn group ownership, medical/logistics state visibility. |
| Failure mode | If readiness is stale, S3 should show stale/unknown readiness and avoid auto-proceed recommendations. |
| Next task | Define BLUFOR readiness read model before broad consumers expand. |

### L8 - Threat Synthesis

| Field | Contract |
|---|---|
| Owner subsystem | Threat / IED |
| Authority | Server owns threat records, economy, scheduler decisions, world manifestations, and lifecycle transitions. |
| Inputs | Terrain/world registry, time policy, CIVSUB RED/WHITE/GREEN, OPFOR capacity when available, recent incidents, player conduct, protected zones, runtime budget. |
| Outputs | Threat records, threat economy snapshot, allow/deny decisions, leads, IED/VBIED/suicide manifestations through incident-driven paths, event feed. |
| State keys | `threat_v0_*`, `ARC_pub_threat*`, IED/VBIED runtime keys, EOD disposition approvals. Full map remains in Threat/IED docs and State Ownership Ledger. |
| Writer functions | Threat init/scheduler/governor/create/update/broadcast functions, IED/VBIED spawn/lifecycle/disposition functions. |
| Event types | `THREAT_CREATED`, `THREAT_STATE_CHANGED`, `THREAT_CLOSED`, `THREAT_CLEANED`, `THREAT_EVENT_DENIED`, `IED_DISCOVERED`, `IED_NEUTRALIZED`, `VBIED_DETONATED`. |
| Tick cadence | Threat scheduler interval, IED/VBIED spawn ticks, cleanup/disposition paths. Must respect runtime policy and protected zones. |
| Persistence | Threat records and bounded history require versioning/reset behavior. World objects remain cleanup-safe and reconstructable only through intended lifecycle. |
| Runtime budget | Threat pressure must use budgets, cooldowns, escalation tiers, and runtime caps. No disconnected random spawn pressure. |
| UI exposure | Threat UI snapshot, threat economy summary, event feed, leads, console explanations, EOD/IED disposition where role-gated. |
| Tests | Threat economy sweep, multi-district posture run, IED evidence/disposal flow, protected-zone denial proof, JIP observer, dedicated restart. |
| Failure mode | If threat synthesis cannot evaluate inputs, deny event with stable reason and log rather than spawning. |
| Next task | Run CIVSUB / Threat / IED reliability sweep before adaptive behavior changes. |

### L9 - Intel / S2

| Field | Contract |
|---|---|
| Owner subsystem | Intel / TASKENG |
| Authority | Server owns lead creation, confidence, uncertainty, and public intel products. Clients may submit sightings/reports through validated routes. |
| Inputs | Threat records, CIVSUB district posture, OPFOR network if available, BLUFOR reports, government posture, time, terrain, ISR/task outcomes. |
| Outputs | Leads, lead confidence, uncertainty labels, intel log, source quality, grid precision, task/lead promotion hints. |
| State keys | Intel log, lead pool, thread/case records, future confidence fields. Full key map requires audit. |
| Writer functions | Intel init/tick/log functions, lead create/broadcast/consume functions, thread/case functions, validated report handlers. |
| Event types | `INTEL_LEAD_CREATED`, `INTEL_CONFIDENCE_CHANGED`, `INTEL_SOURCE_UPDATED`, `LEAD_PROMOTED_TO_TASK`, `LEAD_EXPIRED`, `SIGHTING_REPORTED`. Planned taxonomy where not already logged. |
| Tick cadence | Mostly event-driven. Intel metrics tick exists and should remain bounded. |
| Persistence | Lead/thread/case stores must stay bounded, versioned where persisted, and reset-safe. |
| Runtime budget | Should not spawn physical entities. Output complexity must remain bounded. |
| UI exposure | Intel / Leads tab, dashboard summaries, tasking lead promotion, map markers, diary/console reports. |
| Tests | Lead confidence input audit, lead lifecycle smoke, JIP lead visibility, stale/uncertain UI display, reset/rebuild ghost lead check. |
| Failure mode | If confidence inputs are missing, mark confidence derived/unknown and avoid precise false certainty. |
| Next task | Define intel quality inputs and lead fidelity fields. |

### L10 - Operations / S3

| Field | Contract |
|---|---|
| Owner subsystem | TASKENG / SITREP / Command |
| Authority | Server owns task, queue, orders, SITREP, closeout, and follow-on decisions. Clients request actions through role/proximity-gated paths. |
| Inputs | Intel leads, threat records, BLUFOR readiness, sustainment, terrain, time, civilian/government posture, player reports. |
| Outputs | Tasks, active incident state, queue, orders, follow-on decisions, unit status updates, task/lead closure events, public snapshots. |
| State keys | `ARC_active*`, queue/order public keys, lead pool, task/thread/case stores, unit status snapshots. Full map lives across State Ownership Ledger and TASKENG docs. |
| Writer functions | TASKENG, incident, SITREP, TOC request, queue/order broadcast, lead/thread lifecycle functions. |
| Event types | `TASK_CREATED`, `TASK_ACCEPTED`, `TASK_STARTED`, `TASK_COMPLETE_PENDING_SITREP`, `SITREP_RECEIVED`, `FOLLOW_ON_ISSUED`, `TASK_CLOSED`, `LEAD_PROMOTED`. |
| Tick cadence | Incident loop/watchdog/tick plus event-driven TOC/SITREP actions. |
| Persistence | Active tasks, queues, orders, leads, threads, and closed history must be bounded, reset-safe, and migration-safe. |
| Runtime budget | Should pace mission tempo and avoid task stacking. Does not own ambient spawn budgets. |
| UI exposure | Tasking, SITREP, dashboard, orders, follow-on, Assigned Task Helper, Role/Permission Helper. |
| Tests | End-to-end hosted MP command cycle, SITREP gate parity, reset/rebuild, dedicated restart after active task, JIP during active/follow-on state. |
| Failure mode | If required inputs are stale, hold or request update rather than auto-proceed. |
| Next task | Run TASKENG / SITREP / follow-on reliability sweep and define follow-on policy matrix. |

### L11 - Sustainment / S4

| Field | Contract |
|---|---|
| Owner subsystem | Logistics / Medical |
| Authority | Server owns sustainment snapshots and lifecycle state. Clients submit reports/requests through validated flows. |
| Inputs | SITREP ACE/LACE, medical casualties, logistics convoys, CASEVAC requests, vehicle/equipment status, detainee transport, base services, runtime policy. |
| Outputs | Sustainment readiness, CASEVAC status, convoy state, resupply requests, medical readiness, follow-on constraints for S3. |
| State keys | Medical snapshots, convoy/logistics state, CASEVAC leads, SITREP supply annexes. Full map requires audit. |
| Writer functions | Medical broadcast/tick/casualty functions, logistics convoy functions, SITREP supply validation/build functions, CASEVAC request handlers. |
| Event types | `SUSTAINMENT_STATUS_CHANGED`, `CASEVAC_REQUESTED`, `CASEVAC_CLOSED`, `CONVOY_SPAWNED`, `CONVOY_CLEANED`, `RESUPPLY_REQUESTED`, `MEDICAL_STATUS_CHANGED`. Planned taxonomy where not already logged. |
| Tick cadence | Medical slow recovery, convoy ticks, event-driven SITREP and CASEVAC updates. |
| Persistence | Persistent readiness only where required. Many readiness snapshots should be derivable from active state. |
| Runtime budget | Convoys and physical support assets must respect cleanup and runtime budgets. |
| UI exposure | Medical command, logistics/convoy status, SITREP annex, dashboard readiness, follow-on recommendations. |
| Tests | Convoy spawn/tick/cleanup, casualty accounting, CASEVAC sender binding, resupply request, dedicated/JIP after state changes. |
| Failure mode | If sustainment is stale/unknown, S3 recommendations should bias toward Hold/RTB rather than Proceed. |
| Next task | Define sustainment readiness snapshot and follow-on policy hints. |

### L12 - Interface

| Field | Contract |
|---|---|
| Owner subsystem | UI / Console VM |
| Authority | Client owns local UI state only. Server owns all gameplay state and validates all actions. |
| Inputs | Console VM sections, documented `ARC_pub_*` snapshots, role/station permissions, freshness metadata, action availability reasons. |
| Outputs | Rendered tabs, helpers, toasts, prompts, local selections, validated client requests. |
| State keys | `uiNamespace` local state, Console VM payload, legacy public snapshot reads during migration. No authoritative writes. |
| Writer functions | UI painters and adapters write local UI state only. Server request handlers perform authoritative mutations after validation. |
| Event types | `UI_ACTION_REQUESTED`, `UI_ACTION_DENIED`, `VM_SECTION_STALE`, `CONSOLE_TAB_RENDERED`, `TOAST_EMITTED`. Planned taxonomy where useful. |
| Tick cadence | UI refresh/render cadence only. Must not create gameplay scheduler behavior. |
| Persistence | None for local UI except safe client preferences if later authorized. Gameplay state never persists from UI. |
| Runtime budget | UI must tolerate stale/missing data and avoid expensive polling. |
| UI exposure | All player-facing command, field, tower, intel, sustainment, and diagnostics surfaces. |
| Tests | Console tab source map, VM freshness/staleness display, role/station gating, legacy parity, JIP UI reconstruction, action denial tests. |
| Failure mode | Show stale/unknown/denied state with reason. Do not clear to false no-data or issue state-changing actions locally. |
| Next task | Map each tab to VM sections and remove direct-read debt by parity. |

---

## 6) Update requirements by change type

| Change type | Required ledger action |
|---|---|
| New public snapshot | Update the producing layer and L3. Add UI exposure if consumed by L12. |
| New event envelope | Update producer layer, consumer layer, and L3 event rules. |
| New scheduler or cadence change | Update owning layer tick cadence and L0 runtime budget if relevant. |
| New config value | Update owning layer and Configuration Ownership Ledger when applicable. |
| New authoritative writer | Update owning layer and State Ownership Ledger. |
| New UI tab/helper/action | Update L12 and the authoritative layer that validates the action. |
| New threat/intel/tasking feedback loop | Update all affected layers and the feedback-loop catalog in the ecosystem architecture document. |
| Runtime validation completed | Update tests/failure mode fields if the proof changes the layer status. |

---

## 7) Closure criteria

The layer ledger is complete enough for current architecture work when:

1. Each layer has a current owner and authority boundary.
2. Every public state family maps to a producing layer.
3. Every planned layer expansion has a narrower implementation task or spec.
4. Every `PLANNING` layer is clearly blocked from runtime expansion until scoped.
5. Every `BLOCKED_RUNTIME` layer has a test path into `tests/TEST-LOG.md`.
6. UI consumers know whether they read Console VM, `ARC_pub_*`, or a temporary legacy source.
7. The State Ownership Ledger and Configuration Ownership Ledger cross-reference ecosystem ownership where useful.

---

## 8) Relationship to active documents

| Document | Relationship |
|---|---|
| `docs/architecture/Farabad_Ecosystem_Architecture_v1.md` | Parent ecosystem model. This ledger expands its layer schema into enforceable per-layer rows. |
| `docs/architecture/State_Ownership_Ledger.md` | Single-writer ledger. This layer ledger does not replace key-level writer records. |
| `docs/architecture/Configuration_Ownership_Ledger.md` | Config owner ledger. This layer ledger supplies the ecosystem owner dimension. |
| `docs/architecture/Console_VM_v1.md` | UI view-model contract. L12 uses it as the preferred UI data source. |
| `docs/planning/Task_Decomposition.md` | Execution-track document. Track 8 owns ecosystem-layer enforcement. |
| `docs/qa/Pre_Dedicated_Mission_Completion_Audit_2026-04-06.md` | Completion ledger before dedicated/JIP. Runtime statuses in this layer ledger must not override it. |
| `docs/planning/Subsystem_Reliability_and_Adaptive_COIN_Plan.md` | Reliability-first execution contract. L4, L8, L10, and L11 runtime proof should flow through that plan. |
| `docs/security/RemoteExec_Endpoint_Audit_Matrix.md` | RPC security ledger. UI/action paths in L12 must update it when request surfaces change. |
| `AGENTS.md` | PR mode doctrine. Updates to this ledger are Mode F unless they are bundled incorrectly with runtime behavior, which is not allowed. |

---

## 9) Update policy

Update this ledger when any of the following changes:

- A layer gains, loses, or changes authoritative ownership.
- A public snapshot, state key family, config family, or event envelope crosses layer boundaries.
- A layer status changes after implementation or runtime validation.
- A new implementation spec narrows a planning-only layer into buildable work.
- A future architecture plan changes phase order, subsystem boundaries, or non-goals.
