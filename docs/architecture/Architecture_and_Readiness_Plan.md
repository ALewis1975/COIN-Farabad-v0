# Farabad COIN v0 — Architecture & Readiness Plan

**Version:** 1.0  
**Date:** 2026-02-23  
**Source:** Synthesized from agent-thread audit (steps 1–7), RPT evaluation (Arma3_x64_2026-02-22), and existing project documentation.

---

## 1. Executive Summary

COIN Farabad v0 is a 79-slot dedicated-server Arma 3 COIN sandbox comprising **426 SQF functions** across **12 subsystems**. The architecture follows a **server-authoritative single-writer** model where clients consume read-only snapshots.

**Current status:** Structurally sound. The authority model, replication strategy, and RPC validation patterns are consistently applied. Three P0 fixes were applied in this thread (compile audit execution, CIVSUB isNil, lightbar). One remaining P0 bug blocks CIVSUB identity generation. CI compatibility gaps exist in airbase and threat subsystems.

**Readiness assessment:** CONDITIONAL GO for continued development. GO for multiplayer testing of non-CIVSUB workflows. The minimum fix set (§8) must land before CIVSUB interaction is viable.

---

## 2. System Map

### 2.1 Subsystem Inventory

```
┌─────────────────────────────────────────────────────────────┐
│                     initServer.sqf                          │
│              (config overrides, build stamp)                 │
│                         │                                   │
│                         ▼                                   │
│              fn_bootstrapServer                             │
│     (world reg, state load, tunables, rehydrate)            │
│              │              │              │                 │
│              ▼              ▼              ▼                 │
│     ┌── STATE ──┐   ┌── LOOPS ──┐   ┌── SUBSYSTEMS ──┐     │
│     │ stateInit │   │ incident  │   │ CIVSUB          │     │
│     │ stateGet  │   │ Loop(60s) │   │ AIRBASE         │     │
│     │ stateSet  │   │ execLoop  │   │ THREAT          │     │
│     │ stateSave │   │ (5s)      │   │ IED/VBIED       │     │
│     │ stateLoad │   │ watchdog  │   │ CASREQ          │     │
│     └───────────┘   │ Loop      │   │ LOGISTICS       │     │
│           │         └───────────┘   └─────────────────┘     │
│           ▼                                                 │
│   fn_publicBroadcastState                                   │
│   fn_statePublishPublic                                     │
│           │                                                 │
│           ▼ (setVariable [..., true])                       │
│   ARC_pub_state + ARC_pub_stateUpdatedAt                    │
│           │                                                 │
├───────────┼─────────────────────────────────────────────────┤
│ CLIENT    │                                                 │
│           ▼                                                 │
│   initPlayerLocal.sqf                                       │
│   (PV event handler + 2s fallback poll)                     │
│           │                                                 │
│           ▼                                                 │
│   ┌── UI CONSOLE ──┐  ┌── BRIEFING ──┐  ┌── TOC INIT ──┐  │
│   │ Dashboard      │  │ updateClient │  │ addActions    │  │
│   │ Ops / Intel    │  │              │  │ (mobile ops)  │  │
│   │ S1/S2/Air/CMD  │  └──────────────┘  └───────────────┘  │
│   │ Boards / HQ    │                                        │
│   └────────────────┘                                        │
│        │ (RPCs)                                             │
│        ▼ remoteExec [..., 2]                                │
│   Server-side handlers with rpcValidateSender               │
└─────────────────────────────────────────────────────────────┘
```

### 2.2 Subsystem Detail

| # | Subsystem | Files | Authority | Purpose | Key State |
|---|-----------|-------|-----------|---------|-----------|
| 1 | **Core/State** | 132 | Server | Persistent state, incident lifecycle, threading, roles, cleanup | `ARC_state` (326 keys, schema v7) |
| 2 | **CIVSUB** | 99 | Server (sim) + Client (dialog) | Civilian population, identity, district influence, interaction | `civsub_v1_*` (~24 keys), identity store |
| 3 | **UI/Console** | 68 | Client-only | Multi-tab tactical console, role-gated views | `uiNamespace` only |
| 4 | **Airbase** | 41 | Server | Runway clearance, flight queue, ATC | `airbase_v1_*` |
| 5 | **Command/Intel** | 34 | Server | TOC queue, order issuance, map-click intel | `tocQueue`, `tocOrders` |
| 6 | **IED/VBIED** | 15 | Server | Explosive lifecycle, evidence, EOD | `activeIed*`, `activeVbied*` |
| 7 | **Threat** | 8 | Server | Per-task threat assessment, state tracking | `threat_v0_records` |
| 8 | **World** | 7 | Server (init) | Marker/zone registration, spawn locations | `ARC_worldZones` |
| 9 | **Ops** | 5 | Server | Composition spawning (patrol contacts, support) | Via `activeExec*` |
| 10 | **CASREQ** | 4 | Server | Close air support request queue | `casreq_v1_*` |
| 11 | **Intel** | 4 | Server | Intel init, metrics tick | Via `ARC_state` |
| 12 | **Logistics** | 2 | Server | Convoy spawning and tick | `activeConvoy*` |

---

## 3. Authority & Replication Model

### 3.1 Write Model

| Layer | Written from | Replicated? | Purpose |
|-------|-------------|-------------|---------|
| `ARC_state` | Server only | No | Authoritative internal state |
| `ARC_pub_state` | Server only | Yes (`setVariable [..., true]`) | Client-readable snapshot |
| `ARC_pub_stateUpdatedAt` | Server only | Yes | Change-detection token |
| `ARC_pub_queue` / `ARC_pub_orders` | Server only | Yes | TOC queue/order snapshots |
| `uiNamespace` variables | Client only | Never | Local UI state |
| Object variables | Owner (server for AI) | Varies | Per-entity state |

**Verified clean patterns:**
- ✅ Zero `publicVariable` calls in entire codebase — all replication via `setVariable [..., true]`
- ✅ UI functions never write to `missionNamespace` with broadcast flag
- ✅ UI functions never reference `ARC_state` directly — only `ARC_pub_*` snapshots
- ✅ All server-only functions have `if (!isServer) exitWith` as first line
- ✅ All client-only functions have `if (!hasInterface) exitWith` as first line

### 3.2 RPC Surface

Client→Server RPCs use `remoteExec ["ARC_fnc_*", 2]` and are validated by `fn_rpcValidateSender`:
1. `remoteExecutedOwner` must exist
2. Caller object must not be null
3. `owner(_caller)` must match `remoteExecutedOwner`
4. Failures logged to intel log with structured metadata

**Gap:** `CfgRemoteExec` allowlist is documented in `docs/security/RemoteExec_Hardening_Plan.md` (35+ endpoints cataloged) but **not yet implemented** in `description.ext`. The engine currently operates in default permissive mode.

### 3.3 Client Snapshot Delivery

Clients receive state via:
1. **Primary:** `addPublicVariableEventHandler` on `ARC_pub_stateUpdatedAt` (event-driven)
2. **Fallback:** 2-second polling loop in `initPlayerLocal.sqf` (resilience for missed PV events)
3. **JIP:** Wait for `ARC_serverReady` gate (35s timeout) → initial refresh → event subscription

---

## 4. Task Lifecycle (Command Cycle)

```
  ┌──────────┐   TOC generates    ┌──────────┐  Leader accepts   ┌──────────┐
  │   NONE   │ ─────────────────► │ CREATED  │ ────────────────► │ ACCEPTED │
  └──────────┘                    └──────────┘                   └────┬─────┘
       ▲                                                              │
       │                                                    execInitActive
       │                                                              │
       │                                                              ▼
  ┌────┴─────┐  incidentClose     ┌──────────┐   SITREP sent   ┌──────────┐
  │  CLOSED  │ ◄──────────────── │  CLOSE   │ ◄────────────── │EXECUTING │
  └──────────┘  (TOC confirms)   │  READY   │  (+ watchdog)   └──────────┘
                                  └──────────┘
```

**Key gates:**
- **Accept gate:** Role-authorized player, incident not already accepted
- **SITREP gate:** Incident accepted, proximity to AO, one SITREP per incident, role check
- **Close gate:** SITREP received (or watchdog timeout), TOC closeout order, optional follow-on
- **Watchdog:** Unaccepted timeout (900s), accepted stall timeout (1800s) → suggest close

---

## 5. Findings Summary

### 5.1 Resolved (This Thread)

| ID | Finding | Fix | File |
|----|---------|-----|------|
| **P0-1** | Compile audit executed function bodies, causing RPT noise and state mutation | Changed `[] call compile` → `compile` (compile-only); added 15s debounce | `fn_devCompileAuditServer.sqf` |
| **P0-2** | CIVSUB Background Check always failed at IDENTITY_TOUCH due to `isNil` semantics | Added trailing variable in `isNil` blocks (lines 152, 201) | `fn_civsubContactActionBackgroundCheck.sqf` |
| **P1** | Lightbar init hardcoded missing vehicle names | Made targets configurable via `ARC_lightbarTargets` | `ARC_lightbarStartupServer.sqf` |

### 5.2 Outstanding

| ID | Sev | Finding | File(s) | Fix Description |
|----|-----|---------|---------|-----------------|
| **F1** | **P0** | `isNil` bug in `fn_civsubIdentityTouch.sqf:38,48` — same root cause as P0-2. New civilians never get identity records. | `fn_civsubIdentityTouch.sqf` | Add trailing var: `isNil { _tmpUid = ...; _tmpUid }` and `isNil { _tmpRec = ...; _tmpRec }` |
| **F2** | P1 | `toUpperANSI`/`toLowerANSI` in **14 files** (53 occurrences) — CI sqflint rejects. Heaviest: `fn_airbaseTick.sqf` (15), `fn_publicBroadcastState.sqf` (15) | 14 files across ambiance/, core/, casreq/ | Replace with `toUpper`/`toLower` |
| **F3** | P1 | `findIf` in **55 files** (~110 occurrences) — CI sqflint rejects. Spans all subsystems. | 55 files across all subsystem dirs | Replace with `forEach` + `exitWith` |
| **F4** | P1 | Bare `createHashMapFromArray` in **41 files** — sqflint rejects | 41 files across civsub/, core/, ui/, command/ | Wrap in `_hmCreate` compile helper |
| **F5** | P1 | No `CfgRemoteExec` allowlist in `description.ext` | `description.ext` | Implement allowlist per `RemoteExec_Hardening_Plan.md` |
| **F6** | P2 | Unbounded `intelLog`, `incidentHistory`, `metricsSnapshots` arrays | `fn_stateInit.sqf`, `fn_publicBroadcastState.sqf` | Add max-size caps with prune-on-write |
| **F7** | P2 | Guard post `AllUnits` iteration — O(N×M) per guard unit per cycle | `fn_guardPost.sqf` | Add distance/side pre-filter |
| **F8** | P2 | State write race — `fn_stateSet` does unsynchronized read-modify-write | `fn_stateSet.sqf` | Queue-and-flush or atomic upsert pattern |

---

## 6. Scheduler & Loop Inventory

| Loop | Location | Cadence | Context | Risk |
|------|----------|---------|---------|------|
| Incident tick | `fn_incidentLoop` | `sleep 60` | Scheduled, server | LOW |
| Exec tick | `fn_execLoop` | `sleep 5` | Scheduled, server | LOW |
| Watchdog | `fn_incidentWatchdogLoop` | `sleep 10-60` | Scheduled, server | LOW |
| Airbase tick | `fn_airbaseInit` | `sleep 2` | Scheduled, server | MEDIUM (scales with traffic) |
| CIVSUB tick | `fn_civsubInitServer` | `sleep 60` | Scheduled, server | LOW |
| CIVSUB scheduler | `fn_civsubSchedulerInit` | `sleep 300` | Scheduled, server | LOW |
| CIVSUB traffic | `fn_civsubTrafficInit` | `sleep 1` | Scheduled, server | MEDIUM (bounded by cap) |
| Snapshot watcher | `initPlayerLocal.sqf` | `uiSleep 2` | Scheduled, client | LOW (fallback only) |
| Console keepalive | `initPlayerLocal.sqf` | `uiSleep 0.25` | Scheduled, client | LOW (gated by adaptive timer) |
| Console refresh | `fn_uiConsoleOnLoad` | `uiSleep 0.2` | Scheduled, client | LOW (display-bound) |

No per-frame handlers (`onEachFrame`, `CBA_fnc_addPerFrameHandler`) detected. ✅

---

## 7. Architectural Vision — Forward Plan

### Phase 1: Stabilize (Next PR)

**Goal:** Fix all P0/P1 bugs so CIVSUB interactions work and CI passes clean.

| Item | Effort | Files |
|------|--------|-------|
| Fix `isNil` in `fn_civsubIdentityTouch.sqf:38,48` | 2 lines | 1 file |
| Replace `toUpperANSI`/`toLowerANSI` across codebase | 53 replacements | 14 files |
| Replace `findIf` across codebase | ~110 occurrences (~300 LOC) | 55 files (split by subsystem) |
| Wrap bare `createHashMapFromArray` across codebase | ~80 call sites | 41 files (split by subsystem) |

### Phase 2: Harden (Security + Resilience)

**Goal:** Close the CfgRemoteExec gap, cap unbounded arrays, and improve state write safety.

| Item | Effort | Reference |
|------|--------|-----------|
| Implement `CfgRemoteExec` allowlist in `description.ext` | Medium — 35+ entries from hardening plan | `docs/security/RemoteExec_Hardening_Plan.md` |
| Cap `intelLog` / `incidentHistory` / `metricsSnapshots` with prune-on-write | Low | `fn_stateSet.sqf` or dedicated pruner |
| Optimize `fn_guardPost.sqf` AllUnits scan | Low | Distance + side pre-filter |

### Phase 3: Performance & Validation

**Goal:** Dedicated-server QA pass to validate JIP, persistence, and performance under load.

| Item | Status | Notes |
|------|--------|-------|
| Local MP smoke test | BLOCKED | Requires Arma 3 runtime |
| Dedicated server + JIP synchronization | BLOCKED | All TEST-LOG entries currently BLOCKED |
| Late-client recovery | BLOCKED | Requires dedicated server environment |
| Console VM v1 migration | PLANNED | Migrate from direct `ARC_pub_*` reads to structured View Model (`docs/architecture/Console_VM_v1.md`) |
| CIVSUB lead-emit bridge | PLANNED | Materialize CIVSUB-sourced leads into core `leadPool` (`docs/architecture/CIVSUB_Incident_Lead_Permutation_Matrix.md`) |

### Phase 4: Feature Completion

**Goal:** Complete remaining subsystem integration and behavioral coverage.

| Item | Reference |
|------|-----------|
| TASKENG thread/task hierarchy (parent-case pattern) | `docs/projectFiles/Farabad_TASKENG_Thread_Task_Hierarchy*` |
| SITREP gate parity enforcement | `docs/architecture/SITREP_Gate_Parity.md` |
| Console tab migration (remaining tabs) | `docs/planning/Console_Tab_Migration_Plan.md` |
| Airbase control state reset rollback | `docs/qa/AIRSUB_Control_Reset_and_Rollback.md` |

---

## 8. Minimum Fix Set (Blocking)

Ordered by severity and dependency:

| # | Priority | Finding | Fix | Est. Lines |
|---|----------|---------|-----|------------|
| 1 | **P0** | `fn_civsubIdentityTouch.sqf:38,48` isNil bug | Add trailing var in isNil blocks | 2 |
| 2 | **P1** | `toUpperANSI`/`toLowerANSI` → CI failure | Replace with `toUpper`/`toLower` | 53 (14 files) |
| 3 | **P1** | `findIf` → CI failure | Replace with `forEach` + `exitWith` | ~300 (55 files) |
| 4 | **P1** | Bare `createHashMapFromArray` → CI failure | Wrap in compile helper | ~80 (41 files) |
| 5 | **P1** | `CfgRemoteExec` allowlist missing | Implement per hardening plan | 50 |
| 6 | **P2** | Unbounded state arrays | Add max-size caps | 15 |

---

## 9. Design Principles (Reaffirmed)

These principles are consistently enforced and should remain inviolate:

1. **Server is single writer.** All authoritative state lives in `ARC_state` on the server. Clients never mutate shared state.
2. **Clients consume snapshots.** `ARC_pub_state` is a curated, filtered projection. UI code reads only from `ARC_pub_*` and `uiNamespace`.
3. **RPCs are validated.** Every client→server call passes through `fn_rpcValidateSender` with owner-matching, null checks, and audit logging.
4. **No anonymous remoteExec.** All remote execution uses named `ARC_fnc_*` functions.
5. **Compile helpers for sqflint.** Operators unknown to sqflint (`getOrDefault`, `createHashMapFromArray`, `keys`, `trim`, `fileExists`, `findIf`) are wrapped in `compile "..."` helpers.
6. **Schema-versioned state.** `ARC_state` carries a version number; migrations are explicit.
7. **Structured logging.** All `diag_log` calls use `[ARC][MODULE][LEVEL]` prefix with context metadata.
8. **Idempotent init.** Bootstrap, loop starts, and keepalives use single-run guards to prevent double-initialization.

---

## 10. Document Hierarchy

```
Source of Truth & Workflow Spec (v1.0)
  └── Mission Design Guide (v0.4) ← locked intent
       ├── Project Dictionary (v1.1) ← canonical naming
       ├── ORBAT ← force structure
       └── Subsystem Baselines ← implementation contracts
            ├── TASKENG baseline
            ├── CIVSUB baseline
            ├── AIRBASE baseline
            └── CASREQ baseline

This Document (Architecture & Readiness Plan)
  └── Synthesizes: audit thread findings + RPT evaluation + existing docs
  └── Governs: Phase 1–4 prioritization
```

---

## Appendix A: Key File Reference

| File | Purpose |
|------|---------|
| `initServer.sqf` | Server config overrides, build stamp, safe mode |
| `initPlayerLocal.sqf` | Client bootstrap, snapshot watcher, keepalives |
| `functions/core/fn_bootstrapServer.sqf` | Server init: world reg, state load, tunables |
| `functions/core/fn_stateInit.sqf` | State schema definition (326 keys, v7) |
| `functions/core/fn_stateGet.sqf` / `fn_stateSet.sqf` | State accessors |
| `functions/core/fn_publicBroadcastState.sqf` | Build public snapshot from state |
| `functions/core/fn_statePublishPublic.sqf` | Publish with cadence/staleness guards |
| `functions/core/fn_rpcValidateSender.sqf` | RPC security gate |
| `functions/core/fn_incidentLoop.sqf` | 60s server heartbeat |
| `functions/core/fn_execLoop.sqf` | 5s execution tick |
| `functions/core/fn_incidentCreate.sqf` | Incident generation from catalog/leads |
| `functions/core/fn_incidentClose.sqf` | Incident closure with history capture |
| `functions/core/fn_tocReceiveSitrep.sqf` | SITREP reception and validation |
| `functions/core/fn_devCompileAuditServer.sqf` | Dev tool: compile-only syntax check |
| `config/CfgFunctions.hpp` | Function registry (665 lines) |
| `description.ext` | Mission config (needs CfgRemoteExec) |

## Appendix B: Test Infrastructure

- **Test runner:** `tests/run_all.sqf` — SQF-native test framework with `ARC_TEST_fnc_assert`, logging via `[ARC][TEST][PASS/FAIL]`
- **CI pipeline:** `.github/workflows/arma-preflight.yml` — sqflint compat scan + sqflint lint per changed file
- **Static tests:** `tests/static/` — migration checks
- **Test log:** `tests/TEST-LOG.md` — canonical validation record (most entries BLOCKED due to no Arma 3 runtime in CI)
