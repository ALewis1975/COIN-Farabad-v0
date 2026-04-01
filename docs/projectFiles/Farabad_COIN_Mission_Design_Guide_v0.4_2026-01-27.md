# Farabad COIN Mission Design Guide

**Project:** COIN_Farabad (Farabad AO)  
**Document version:** 0.4 (locked)  
**Last updated:** 2026-01-27 (America/New_York)  
**Purpose:** A shared guide for mission intent, system design, and development priorities.

---

## Change log

### v0.4 — 2026-01-27
- Reconciled document status: this guide is now explicitly **locked** and updated only via version bumps.
- Updated “source of truth” references:
  - Added **Project Dictionary** as the authoritative naming/contracts reference.
  - Added **Threat System v0 + IED Phase 1** as a locked implementation baseline.
- Clarified Threat roadmap:
  - Threat v0 + IED Phase 1 baseline is the near-term implementation target.
  - IED/VBIED/Suicide document remains a **planning spec** for later phases.
- Updated mod preset reference to the latest dated preset file.
- Minor alignment cleanups: ID conventions, canonical marker names, and UI naming to match dictionary.

### v0.3 — 2026-01-02
- Added a **project governance + source-of-truth** section (ORBAT authority, baseline vs planning specs).
- Added **architecture standards** shared across subsystems: single-writer server authority, delta bundles, “consumers never guess,” logging, persistence key conventions.
- Integrated new subsystem baselines/specs:
  - CIVSUBv1 (population + identity + influence plumbing)
  - CASREQv1 (structured CAS request workflow)
  - AIRBASESUB (airbase ambience + hybrid ATC)
  - IED/VBIED/Suicide (threat system expansion plan)
- Updated the “Open decisions” list to reflect what is now locked by v1 baselines.

---

## 0. Governance, scope, and source of truth (read this first)

### 0.1 What this document is (and is not)
This Mission Design Guide is the **top-level system intent** for Farabad COIN.

It **does not** replace subsystem baselines/specs. Instead, it:
- Defines the *mission spine* and gameplay outcomes we’re optimizing for.
- Sets cross-cutting engineering rules (authority, persistence, logging).
- Points to the **authoritative** subsystem docs for implementation details.

**Status policy (v0.4 lock):**
- This guide is **locked** as a top-level intent document.
- Updates must be deliberate and versioned; avoid “silent edits” that cause implementation drift.
- Baselines are the contract: if a baseline contradicts this guide, update this guide (via version bump) or fix the baseline — do not “split reality.”

### 0.2 Document types used in this project
- **Project Dictionary (authoritative):** naming, concepts, IDs, markers, and contract language used across systems/UI/logs.
- **ORBAT (authoritative):** unit names, callsigns, responsibilities, and “who owns what.” Subsystems must not introduce conflicting unit references.
- **Locked baseline (implementation planning):** v1 contracts and hard decisions intended to be built exactly.
- **Planning spec:** forward-looking design for future modules; not yet implemented.

### 0.3 Authoritative project references (v0.4)

**Project dictionary**
- `farabad_project_dictionary_v_1.md`

**Authoritative ORBAT**
- `Farabad_ORBAT.md` (BLUFOR + OPFOR/CIV)

**Locked baselines (implementation planning)**
- `Farabad_CIVSUBv1_Development_Baseline (1).md`
- `Farabad_UI_CASREQ_Thread.md` (contains CASREQ v1 locked baseline)
- `Farabad_THREAT_v0_IED_P1_Baseline_regen.md` (Threat v0 + IED Phase 1)

**Planning specs**
- `Farabad_AIRBASESUB_Airbase_Ambience_Planning_Spec.md`
- `Farabad_IED_VBIED_Suicide_Subsystem_Planning.md`

**Doctrine references (project-maintained list)**
- `US_Army_Doctrine_References.md`

**Mod stack reference**
- `Ambient_Dev_Mods_2026-01-22.html`

### 0.4 Anti-regression operating rule (practical)
- Before implementing or “fixing” a subsystem: **read the locked baseline first**.
- Prefer additive, interface-driven changes; avoid refactors that change behavior without tests/logging.
- If files appear to “revert” or drift unexpectedly, **disable OneDrive sync** for the mission workspace. (OneDrive is a frequent source of silent regressions in mission folders.)

---

## 1. Executive summary (the mission spine)

Farabad COIN is a persistent multiplayer counterinsurgency mission set in a fictionalized Takistan AO with a 2011-era joint footprint.

The mission centers on a realistic command cycle:

1) A TOC (or mobile S3) issues a task or lead.  
2) Authorized leaders accept the mission.  
3) The unit executes, then long-halts, sets security, and consolidates.  
4) The unit submits an ACE/LACE-driven SITREP to higher.  
5) The TOC issues follow-on orders (RTB, Hold, Proceed) based on unit status and METT‑TC.

This “task → action → report → decision → follow-on” loop is the spine of the entire project.

---

## 2. Scenario context and grounded constraints

### 2.1 Setting
- COIN in a semi-permissive environment with an insurgent network, criminal actors, and fragile host-nation forces.
- A joint base serves as the operational hub (airfield, sustainment, medical, base defense, ISR).

### 2.2 Realism constraints the mission enforces
- Units do not instantly pivot from objective to objective without reporting.
- Sustainment matters: liquids, ammo, casualties, and key equipment constrain tempo.
- Enemy presence behaves like a network (cells and facilitators), not a standing front line.

---

## 3. Player experience goals

- **C2 feels real:** leaders accept missions and must report results; the TOC drives pacing.
- **Tempo feels earned:** follow-on missions are gated behind SITREP closure.
- **COIN feels adaptive:** violence and intel quality respond to player conduct and influence conditions.
- **The base feels alive:** service functions, arrivals/departures, convoys, and patrol routines create continuity.
- **The system stays stable:** persistence, task stacking prevention, cleanup, and logging remain first-class.
- **The UI reduces chaos:** the command cycle should be runnable through consistent UI workflows, not scattered actions and voice-only glue.

---

## 4. Architecture standards (cross-cutting rules)

These are mission-wide engineering standards. Subsystems should conform unless explicitly exempted by a locked baseline.

### 4.1 Single-writer authority model (hard requirement)
- The **server** is the single writer for persistent state.
- Clients submit requests; the server validates and publishes updates.

### 4.2 “Consumers never guess” (hard requirement)
If a UI or subsystem needs a fact, it must be explicitly included in the emitted data/event.  
Do not reconstruct state from partial messages or implied transitions.

### 4.3 Delta bundles as the integration bus (recommended standard)
Subsystems should emit structured “delta bundles” (one event → one envelope) containing:
- event identity + timestamp
- actor + target context
- payload (bounded)
- influence deltas (if applicable)
- optional lead/task emission hints

This keeps cross-subsystem coupling clean and testable.

### 4.4 Stable identifiers (required)
Use stable IDs for cross-linking (see Project Dictionary):
- **District IDs:** `D01..D20`
- **Threat IDs:** `THR:Dxx:000123`
- **CASREQ IDs:** `CAS:Dxx:000001`
- Never use human-friendly names as persistence keys.

### 4.5 Persistence format and versioning (recommended standard)
- Persist state as a **JSON blob** in `profileNamespace` (server-authoritative) unless a future database layer replaces it.
- Every persisted subsystem should:
  - store a schema version
  - bump schema version for breaking changes
  - support a “Reset Persistence” workflow that writes a clean, empty state

### 4.6 Logging (hard requirement)
Log every critical transition:
- Task accept/start/complete/SITREP/follow-on
- Threat state transitions
- CASREQ lifecycle transitions
- Airbase clearance decisions and runway locks

Logs must include: timestamp, actor, object ID, and location (grid/marker).

### 4.7 Bounded stores (required for UI history)
Any message/history systems (CAS dialogue threads, closed indexes, UI history lists) must be bounded (caps + TTL where appropriate) to prevent unbounded growth and persistence bloat.

---

## 5. Systems thinking view (how the parts interact)

Treat Farabad COIN as a system-of-systems with feedback loops.

### 5.1 Core subsystems (v1 reality)
1. **Command and Control:** TOC issues tasks; leaders accept; units report; TOC decides follow-on.  
2. **TASKENG (Task and Lead Engine):** tasks generate outcomes; outcomes generate leads; leads convert into tasks.  
3. **SITREPSYS (SITREP + Reporting):** closes operational chains; gates follow-ons; anchors persistence and scoring.  
4. **CIVSUBv1 (Population / Influence):** civilians as “terrain,” district influence, identity layer for touched civilians.  
5. **Threat System v0 + IED Phase 1:** recordkeeping + minimal IED package with logging/cleanup; expandable later.  
6. **Sustainment:** ammo, casualties, equipment, and liquids constrain decisions.  
7. **World Simulation:** base ops, convoys, ambient activity; expandable via AIRBASESUB.  
8. **CASREQ v1 (Air Ops + CAS):** structured requests, clearances, and logging integrated with C2.  
9. **Persistence / State:** mission remembers what happened and prevents duplicates and ghost tasks.

### 5.2 Intended feedback loops
- **Positive COIN loop:** disciplined presence → improved security → more cooperation → better intel → more precise ops → reduced insurgent freedom of action → improved governance posture.
- **Negative COIN loop:** sloppy/heavy-handed ops → grievances → less cooperation → worse intel → broader sweeps → more attacks/recruitment → harder AO.

Use these levers to tune difficulty without turning the AO into a constant spawn grinder.

---

## 6. ORBAT integration (design anchors)

**ORBAT dictates unit references.** Treat `Farabad_ORBAT.md` as authoritative for:
- unit naming and callsigns
- “who owns what”
- UI labels
- logs and task ownership vocabulary

Key gameplay anchors include:
- **TF REDFALCON** (player-centric maneuver TF; primary player company is REDFALCON 3)
- **THUNDER** (MSR control / route security)
- **SHADOW** (ISR)
- **SHERIFF** (MP detainees / evidence)
- **SENTRY** (USAF security forces)
- **RAVEN** (JTAC / TACP)
- **LIFELINE** (medical)

---

## 7. Command post model (TOC + mobile S3 + consoles)

### 7.1 The TOC’s job in gameplay terms
- Maintain a running estimate (unit readiness + AO risk).
- Publish tasks, approve acceptances, and receive SITREPs.
- Decide follow-on based on LACE and METT‑TC.
- Manage escalation pacing so the AO “breathes.”

### 7.2 Mobile S3 (optional forward node)
A mobile S3/TAC CP can:
- Act as a forward tasking node when the main TOC stays at base.
- Receive SITREPs and issue follow-ons inside the AO.
- Reduce dead time by keeping the C2 loop close to maneuver elements.

### 7.3 UI/Dialogue layer as the control surface (recommended)
Prefer **one entry point, many capabilities**:
- Use a station-aware **Farabad Console** UI shell for:
  - Tasking
  - SITREP submission
  - Leads promotion
  - CAS requests
  - Tower clearances (when AIRBASESUB is implemented)

Minimize scattered world actions and bespoke addAction flows to reduce integration tax.

---

## 8. The Task / Lead / SITREP framework (the project spine)

### 8.1 Definitions
- **Task:** a mission order with objective, constraints, success criteria, and an owning HQ.
- **Lead:** actionable intel that points to a follow-on objective; it must convert into a task before execution.

### 8.2 Lifecycle (recommended state model)
- Created → Offered → Accepted → In Progress → Complete (Pending SITREP) → Closed  
- Failure states: Failed (with reason) → Closed or Re-tasked  
- Leads: Discovered → Validated → Promoted to Task → Closed

### 8.3 Role permissions (hard requirement)
Only these roles may accept tasks or submit SITREPs:
- Company Staff: Commander, XO, 1SG  
- Platoon Staff: PL, PSG  
- Squad Leaders

### 8.4 Proximity gating (hard requirement)
Players may submit SITREPs only when they are within the defined radius of:
- The assigned task objective area, or
- The assigned lead location

### 8.5 Logging (hard requirement)
Log both:
- **Task accepting unit**
- **SITREP reporting unit**

These may differ. The system must record:
- Task/lead ID
- Player UID (or unit identity), group, callsign
- Timestamp
- Location (grid/marker)
- Outcome

### 8.6 Consolidation and security (before SITREP)
When a unit completes an objective, the mission should drive:
- Long halt, establish 360 security and sectors
- Casualty treatment and evacuation decisions
- Ammo and equipment checks (ACE/LACE)
- Detainee handling or SSE if applicable
- Route clearance or local stabilization tasks if needed

### 8.7 SITREP payload (recommended minimum)
Include:
- Who: callsign, element, leader role
- Where/when: grid/marker, timestamp
- Task ID and result statement
- ACE/LACE:
  - Liquids
  - Ammo
  - Casualties (KIA/WIA, evac status)
  - Equipment (mobility, comms, key systems)
- Enemy: SALUTE-style summary if relevant
- CIV/GREEN: key changes (checkpoint status, shura outcomes, detainees, aid delivered)
- Requests: resupply, MEDEVAC, QRF, engineer, detainee pickup
- Recommendation: RTB, Hold, Proceed

**Required v1 extension (CIVSUB):** include a CIVSUB annex summary (district deltas, civilian casualties, detentions, aid events) as defined in the CIVSUB baseline.

### 8.8 TOC follow-on outputs (core set)
The TOC issues one of:
1) **RTB** for refit and debrief  
2) **Hold** for security, presence, or overwatch  
3) **Proceed** to the next task or lead

---

## 9. Population / influence model (CIVSUB anchor)

### 9.1 v1 design choice
Influence is district-based with three axes:
- **RED** influence (insurgent intimidation/control)
- **WHITE** sentiment (civilian cooperation/grievance)
- **GREEN** legitimacy (host-nation governance legitimacy)

In v1, these variables directly drive:
- lead generation rate and confidence
- reactive contact/attack probability (in threat systems that consume it later)
- narrative effects (cooperation vs fear vs corruption)

### 9.2 CIVSUBv1 baseline status
CIVSUBv1 is a locked baseline for implementation planning:
- virtual population per district (statistical), not thousands of live AI
- identity records persist only for “touched” civilians
- emits delta bundles as its integration output
- integrates with ACE interactions and (optionally) an ID/passport presentation layer

Refer to `Farabad_CIVSUBv1_Development_Baseline (1).md` for the exact schema, effects table, tick/scheduler math, and persistence keys.

---

## 10. Threat system (network-driven, phased implementation)

**Safety note:** Threat mechanics described in Farabad docs are **gameplay abstractions** (records, state machines, pacing governors). They are not real-world explosive construction or real-world tactics.

### 10.1 Threat System v0 + IED Phase 1 (locked baseline)
Near-term implementation target:

- **Threat v0:** recordkeeping + minimal hooks so threats are tracked, logged, and persistence-safe without changing overall pacing.
- **IED Phase 1:** one contained threat package (`IED_SUSPICIOUS_OBJECT`) spawned only inside the player bubble / AO activation context with full cleanup discipline.

Key integration hooks are intentionally minimal:
- AO activation hook: create threat record(s)
- Incident close hook: close records and cleanup world refs

Refer to `Farabad_THREAT_v0_IED_P1_Baseline_regen.md` for exact schema, missionNamespace keys, idempotency and acceptance tests.

### 10.2 IED/VBIED/Suicide expansion (planning spec)
The `Farabad_IED_VBIED_Suicide_Subsystem_Planning.md` document defines:
- a persistence-first ThreatRecord schema (future version)
- state transitions and fairness guardrails
- event-to-task/lead mapping aligned to the Task/Lead/SITREP spine

This module should be a **child** of the Threat System, not a standalone random spawner.

---

## 11. Air operations: AIRBASESUB + CASREQ (integration direction)

### 11.1 CASREQ v1 (locked baseline)
CAS requests should be a structured workflow (not markers + voice-only):
- requester roles are gated (JTAC/TACP primary; leadership fallback policy as configured)
- CASREQ uses a record + state machine + delta bundles
- the pilot has a cockpit-friendly “inbox” and can submit BDA

The v1 CASREQ baseline lives in `Farabad_UI_CASREQ_Thread.md`.

### 11.2 AIRBASESUB (planning spec with v1 locks)
AIRBASESUB is the airfield portion of base world simulation:
- continuous virtual arrivals/departures while players are active
- hybrid ATC (player controllers + AI fallback)
- physical spawn/despawn within the airbase bubble to protect performance
- parity: rotary-wing uses the same clearance workflow

Key v1 locks include:
- bubble center marker: `mkr_airbaseCenter`
- tower role identifiers: `farabad_tower_lc`, `farabad_tower_ws_ccic`
- AI tower anchor unit variable: `FarabadTower_LA`

Refer to `Farabad_AIRBASESUB_Airbase_Ambience_Planning_Spec.md` for details.

---

## 12. Convoy and sustainment framework

### 12.1 Convoy routing constraint (hard requirement)
Route all convoys approaching the airbase to the **North_Gate** marker and keep them off the airfield. This protects the flightline simulation and reduces pathfinding failures.

### 12.2 Convoy design (recommended)
- Spawn point marker and a visible debug marker during testing
- Spawn direction aligned to route
- Road-follow behavior and convoy separation settings
- Vehicle pools aligned to 2011 and the active mod stack
- Cleanup logic that prevents leftover AI and vehicles

### 12.3 Cleanup and despawn (hard requirement)
Despawn AI, vehicles, and spawned objects when players exit the configured radius to protect performance and reduce state drift.

---

## 13. Base world simulation framework

The base should function as a living joint hub:
- Gate control (barriers, triggers, access control)
- Guardposts and realistic weapon posture behavior (base-security module; not AIRBASESUB v1)
- Flightline and service activity (arrivals, departures, logistics)
- Support spaces (medical, staging, command spaces)
- Clear editor organization (layers and modular compositions)
- “Mayor”/support functions that can emit work orders as tasks (optional, later)

---

## 14. Persistence and reliability standards

Build around these rules:
- Do not allow task stacking (two tasks overwriting or double-loading).
- Do not allow “instant fail” without a visible cause and a clean recovery path.
- Treat “reset persistence” as a primary workflow; avoid ghost leads and legacy tasks.
- Log every critical transition (accept, start, complete, SITREP, follow-on).
- Prefer bounded stores and TTLs (especially for message threads and UI history) to avoid unbounded growth.

---

## 15. Development snapshot (updated)

As of late Jan 2026, development has shifted to contract-first subsystem baselines and minimal-hook integration to avoid regression:

Locked baselines:
- CIVSUBv1 (district influence + civilian identity + delta bundle plumbing)
- CASREQ v1 (structured CAS workflow, roles, state machine, delta bundles)
- Threat v0 + IED Phase 1 (recordkeeping + minimal IED package; AO/incident hook points)

Planning specs:
- AIRBASESUB (airbase virtual schedule + hybrid ATC + bubble gating)
- IED/VBIED/Suicide expansion (ThreatRecord vNext + mapping tables)

---

## 16. Open decisions — status as of roadmap implementation (2026-04)

The following decisions were open in v0.4. Status reflects locks applied
during the 22-item roadmap implementation pass.

| # | Decision | Status | Locked value |
|---|---|---|---|
| 1 | SITREP radius: global vs per-task | **LOCKED** | Single global value `ARC_sitrepProximityM` (default 350 m). Per-task override is deferred post-v1. |
| 2 | Task/SITREP role detection method | **LOCKED** | Explicit station-role identifiers via `ARC_fnc_rolesIsAuthorized`; no ambiguous group-role inference. |
| 3 | TOC control model | **LOCKED** | Hybrid: TOC roles (HQ tokens) for approval actions; field players for SITREP/follow-on requests. |
| 4 | LACE detail level | **DEFERRED** | Numeric counts are default; colored-status UI is a future UX polish task. |
| 5 | Threat/CIVSUB coupling rules | **LOCKED** | `ARC_fnc_threatGovernorCheck` step 6 gates IED budget on district GREEN score (≥ 80 → budget bonus; < 20 → budget penalty). Threshold defaults: 20/80 (configurable). |
| 6 | Mod stack governance | **DEFERRED** | Launcher preset updates remain manual with dated filename convention. Automated governance tracking is a future DevOps task. |

### New decisions locked by roadmap

| Decision | Locked value |
|---|---|
| Adaptive incident loop cadence | Heat-based: 25–90 s range; `ARC_incidentLoopSleepMin` / `ARC_incidentLoopSleepMax` tuneable. |
| Intel lead decay | Linear strength decay toward floor over TTL; `ARC_leadDecayEnabled`, `ARC_leadDecayRate` (0.6), `ARC_leadDecayFloor` (0.05). Expired leads emit "window missed" to intel log. |
| CASEVAC TOC integration | BLUFOR incap → `ARC_fnc_medicalCasevacRequest` → QRF lead in lead pool. Cooldown: 180 s. ACE unconscious EH bridges via CBA. |
| CIV density modulation | RED ≥ `civsub_v1_densityModRedThreshold` (65) → probabilistic spawn suppression (min 10 % floor). `civsub_v1_densityModEnabled` flag. |
| District influence map markers | Per-district ellipse markers updated each broadcast cycle when CIVSUB enabled. Dominant axis drives color. |
| Gate barrier logic | BLUFOR vehicle proximity (default 18 m) auto-opens named Eden barrier objects. Auto-closes after `ARC_worldGateAutoLowerDelayS` (10 s) with no BLUFOR present. |
| KLE task type | 5-min dwell threshold triggers WHITE/GREEN delta + HUMINT lead. `ARC_kleEngageDurationS` tuneable. |
| Route clearance task type | EOD dwell → segment IED suppression for 2 h (`ARC_routeClearSuppressionS`). Evidence → component trace lead. |
| Console VM tab migration path | VM payload (`ARC_consoleVM_payload`) is built every broadcast cycle. Feature flags `ARC_console_dashboard_v2` and `ARC_console_ops_v2` (both default false) enable VM-sourced reads per tab. |
| Mission scoring schema | `ARC_missionScore_v1` composite (0–100) published as `ARC_pub_missionScore`. Rating: UNSAT/MARGINAL/SATISFACTORY/OUTSTANDING. |

---

## 17. References

```text
Authoritative (local project files)
- farabad_project_dictionary_v_1.md
- Farabad_ORBAT.md
- Farabad_CIVSUBv1_Development_Baseline (1).md
- Farabad_UI_CASREQ_Thread.md
- Farabad_THREAT_v0_IED_P1_Baseline_regen.md
- Farabad_AIRBASESUB_Airbase_Ambience_Planning_Spec.md
- Farabad_IED_VBIED_Suicide_Subsystem_Planning.md
- US_Army_Doctrine_References.md
- Ambient_Dev_Mods_2026-01-22.html
```

Public doctrine references should remain limited to official sources; see `US_Army_Doctrine_References.md` for the curated list used by this project.
